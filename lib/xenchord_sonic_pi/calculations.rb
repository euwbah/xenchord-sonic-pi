# Run order: after helper.rb

require 'prime'
require 'fileutils'

##
# Class for dealing with calculations. Create only one of these at startup
class CalcSingleton

  # Stores the log2 of all primes up to $PRIME_LIMIT.
  # @type [Hash<Integer, Float>]
  @log2_primes = nil
  attr_reader :log2_primes

  # Stores the farey sequence.
  # @type [Array<Rational>]
  @farey_seq = nil
  attr_reader :farey_seq

  # Each element is a tuple of [lcm, heuristic_score]
  # @type [Array<Array(Rational, Float, Integer, Float, Array<Array(Integer, Integer)>)>]
  @smooth_height = nil
  attr_reader :smooth_height

  # Initialize Calc class.
  # @param farey_n [Integer] The Nth farey sequence to use. Higher = more accuracy but slower.
  # @param jnd_cents [Float] The number of cents to use for the JND (just noticeable difference).
  def initialize(farey_n: 80, jnd_cents: 5.0)
    raise "farey_n (#{farey_n}) cannot be greater than $PRIME_LIMIT (#{PRIME_LIMIT})" if farey_n > $PRIME_LIMIT
    $GLO.puts "Initializing Calc..."
    $GLO.puts "Calculating log2 of primes. Total: #{$PRIMES.size}"
    @log2_primes = $PRIMES.map { |prime| [prime, Math.log2(prime)] }.to_h

    $GLO.puts "Calculating farey #{}"
    @farey_seq = self.farey(farey_n)
    $GLO.puts "Calc.farey size: #{@farey_seq.size}"

    $GLO.puts "Pre-calculating smooth height metric..."

    # smooth_lcm should be sorted in increasing interval size.
    # Does not include 2/1, which should be specially handled when actually calculating smooth LCM
    # of chords.
    # @param ratio [Rational]
    # @param idx [Integer]
    smooth_lcm_pre = @farey_seq.each.map { |ratio|
      cents = Math.log2(ratio) * 1200.0
      lcm = ratio.numerator * ratio.denominator # fact: num and den are coprime
      lcm /= 2 while lcm % 2 == 0 # reduce lcm by octaves. Octaves should be counted separately, not in this lookup.
      prime_fac = lcm.prime_division

      # For now, assume that the LCM metric works perfectly fine for all intervals that fall
      # under this condition:
      is_fundamental = prime_fac.all? { |base, pow|
        base == 2 || (base == 3 && pow <= 2) || (base == 5 && pow <= 1)
      }
      weight = prime_fac.reduce(1.0) { |acc, (base, pow)|
        case base
        when 2
          acc # don't reduce weight based on octaves, weight is negligible due to further distance weighting
        when 3
          pow <= 2 ? acc : acc / (pow - 1) / (@log2_primes[3] / 2 - 1)
        when 5
          pow <= 1 ? acc : acc / pow / (@log2_primes[5] / 2 - 1)
        else
          acc / pow / (@log2_primes[base] / 2 - 1)
        end
      }
      [ratio, cents, lcm, prime_fac, is_fundamental, weight]
    }

    # Add remaining primes that haven't been added yet. Including these in the Farey series would be
    # too computationally expensive, and the farey series is already dense enough... so this should suffice.

    # @param prime [Integer]
    $PRIMES.filter {_1 > farey_n}.each do |prime|
      oct_reduced = prime.to_r / 2 ** (Math.log2(prime).floor)
      cents = 1200.0 * Math.log2(oct_reduced)
      lcm = prime
      prime_fac = [[prime, 1]]
      is_fundamental = false
      weight = 1.0 / (@log2_primes[prime] - 1)
      # this points to the next largest interval than the current prime
      # TODO: Is this faster than than just appending and sorting at the end?
      insert_idx = smooth_lcm_pre.bsearch_index { |data|
        data[1] > cents
      }

      entry = [oct_reduced, cents, lcm, prime_fac, is_fundamental, weight]

      smooth_lcm_pre.insert(insert_idx, entry)
    end

    @smooth_height = smooth_lcm_pre.each_with_index.map{ |(ratio, cents, lcm, prime_fac, is_fundamental, weight), idx|
      # Fundamental intervals should should have heuristic score of its own lcm
      next [ratio, cents, lcm, lcm.to_f, prime_fac] if is_fundamental

      # otherwise, look for surrounding neighbours, up to +/- 40 cents

      # @type [Array<Array(Integer, Float)>]
      neighbours = []
      curr_idx = idx
      oct_offset = 0
      loop do # going forwards
        curr_idx += 1
        if curr_idx >= smooth_lcm_pre.size
          curr_idx = 0
          oct_offset += 1
        end
        nei_ratio, nei_cents, nei_lcm, nei_prime_fac, nei_is_fund, nei_weight = smooth_lcm_pre[curr_idx]
        distance = nei_cents + 1200.0 * oct_offset - cents
        break if distance > 40

        # Only add neighbour if it improves the heuristic score.
        # The ear tends to 'autocorrect' intervals.
        next unless nei_lcm <= lcm

        # heuristic model: at the JND threshold, distance weight is 0.5
        distance_weight_mult = 2 ** (-distance / jnd_cents)
        neighbours << [nei_lcm, nei_weight * distance_weight_mult]
      end

      curr_idx = idx
      oct_offset = 0
      loop do # going backwards
        curr_idx -= 1
        if curr_idx < 0
          curr_idx = smooth_lcm_pre.size - 1
          oct_offset -= 1
        end
        nei_ratio, nei_cents, nei_lcm, nei_prime_fac, nei_is_fund, nei_weight = smooth_lcm_pre[curr_idx]
        distance = nei_cents + 1200.0 * oct_offset - cents
        break if distance < -40
        next unless nei_lcm <= lcm
        distance_weight_mult = 2 ** (distance / jnd_cents)
        neighbours << [nei_lcm, nei_weight * distance_weight_mult]
      end

      # take weighted average

      total_weight = neighbours.reduce(weight) { |acc, (lcm, w)| acc + w }
      lcm_averaged = neighbours.reduce(lcm * weight) { |acc, (lcm, w)| acc + lcm * w } / total_weight

      # if lcm == 28
      #   $GLO.puts "lcm: #{lcm}, weight: #{weight}, total_weight: #{total_weight}, lcm_heur: #{lcm_averaged}"
      #   $GLO.puts "neighbours: #{neighbours}"
      # end

      [ratio, cents, lcm, lcm_averaged, prime_fac]
    }

    $GLO.puts "Saving smooth height to .csv"
    FileUtils.mkdir_p("#{$LIB_ROOT}/../../data")
    File.open("#{$LIB_ROOT}/../../data/smooth_height.csv", "w") do |f|
     f.puts "ratio,cents,lcm,lcm_heur,prime_fac"
      @smooth_height.each do |ratio, cents, lcm, lcm_heur, prime_fac|
        pf_json = prime_fac.to_s.gsub(",","\\,")
        f.puts "#{ratio},#{cents},#{lcm},#{lcm_heur},#{pf_json}"
      end
    end

    $GLO.puts "Calc initialized."
  end

  # n: The nth farey sequence to output
  # This isn't exactly the farey sequence:
  # - numerator and denominator are swapped
  # - only second half of the sequence returned
  # - sequence in reverse order
  #
  # Makes it more applicable for musical uses.
  # This function returns 1 octave of unique JI intervals up to given n odd limit.
  # Returns a list of Rationals
  #
  # This algo runs in O(n) :)
  #
  # @param n [Integer] The nth farey sequence to output
  # @return [Array<Rational>] The farey sequence
  def farey (n)
    # x1/y1 stores the kth term, x2/y2 stores the (k+1th) term
    x1, y1 = 1,2
    x2, y2 = (n/2.0).ceil, (n/2.0).ceil * 2 - 1
    terms = [Rational(y1, x1), Rational(y2, x2)]
    x = 0, y = 0
    while y != 1
      c += 1
      z = ((y1 + n) / y2).floor
      x = z * x2 - x1
      y = z * y2 - y1
      terms.append(Rational(y,x))
      x1 = x2
      x2 = x
      y1 = y2
      y2 = y
    end
    return terms.reverse
  end

  # Get polyadic smooth lcm.
  # This is quite a bad heuristic score - an attempt at polyadic harmonic entropy with only precomputed dyads,
  # instead of populating the entire n-adic lattice (there's too many of them).
  # Though, it works as long as there's only one 'complicated' interval within the chord, and the other intervals
  # can be expressed as simple intervals relative to the 'complicated' interval.
  # @param lcm_primes [Hash<Integer, Integer>] Prime factorized lcm hash of the entire chord.
  # @param power_2 [Float] How much to the final score powers of 2 should contribute.
  #                1.0 means full octave equivalence (octaves are infinitely consonant). 2.0 means zero octave equivalence.
  def poly_smooth_lcm(lcm_primes, power_2: 1.13)
    result = 1.0 * power_2 ** lcm_primes[2]
    lcm_primes[2] = 0
    lcm = lcm_primes.reduce(1) { |acc, (base, pow)| acc * base ** pow }
    # @type [Array<Array(Rational, Float, Integer, Float, Array<Array(Integer, Integer)>)>]
    remaining = @smooth_height
    while lcm > 1
      max_score = 0
      max_score_interval = nil
      remaining = remaining.filter { |ratio, cents, lcm, lcm_heur, prime_fac|
        within = prime_fac.all? { |base, pow|
          lcm_primes[base] >= pow
        }
        next false if !within # overshoot
        # Greedy:
        # Maximize prime points while minimizing smooth lcm
        prime_points = prime_fac.reduce(0.0) { |acc, (base, pow)|
          acc + base ** pow
        }
        score = prime_points / lcm_heur
        if score > max_score
          max_score = score
          max_score_interval = [lcm, lcm_heur, prime_fac]
        end
        true
      }
      raise "Error! Could not find LCM match for #{lcm_primes}" if max_score_interval.nil?
      best_lcm, best_lcm_heur, best_prime_fac = max_score_interval
      result *= best_lcm_heur
      best_prime_fac.each { |base, pow|
        lcm_primes[base] -= pow
        lcm /= base ** pow
      }
      $GLO.puts "Used best_lcm: #{best_lcm}"
    end
    result
  end
end

# Access calc methods using this Singleton.
$CALC = CalcSingleton.new
