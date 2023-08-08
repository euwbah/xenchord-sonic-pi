# Run order: after helper.rb

require 'prime'
require 'fileutils'

##
# Class for dealing with calculations. Create only one of these at startup
class CalcSingleton

  attr_reader :log2_primes

  attr_reader :farey_seq

  attr_reader :smooth_height

  attr_reader :smooth_height_rat_lookup

  # Initialize Calc class.
  # @param farey_n [Integer] The Nth farey sequence to use. Higher = more accuracy but slower.
  # @param jnd_cents [Float] The number of cents to use for the JND (just noticeable difference).
  def initialize(farey_n: 256, jnd_cents: 7.0)
    raise "farey_n (#{farey_n}) cannot be greater than $PRIME_LIMIT (#{PRIME_LIMIT})" if farey_n > $PRIME_LIMIT
    $GLO.puts "Initializing Calc..."
    $GLO.puts "Calculating log2 of primes. Total: #{$PRIMES.size}"

    # Stores the log2 of all primes up to $PRIME_LIMIT.
    # @type [Hash<Integer, Float>]
    @log2_primes = $PRIMES.map { |prime| [prime, Math.log2(prime)] }.to_h

    $GLO.puts "Calculating farey #{}"

    # Stores the farey sequence.
    # @type [Array<Rational>]
    @farey_seq = self.farey(farey_n)
    $GLO.puts "Calc.farey size: #{@farey_seq.size}"

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
          pow <= 2 ? acc : acc / (pow - 2) / 3
        when 5
          pow <= 1 ? acc : acc / (pow - 1) / 5
        else
          acc / pow / base
        end
      }
      [ratio, cents, lcm, Math.log2(lcm), prime_fac, is_fundamental, weight]
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
      weight = 1.0 / prime
      # this points to the next largest interval than the current prime
      # TODO: Is this faster than than just appending and sorting at the end?
      insert_idx = smooth_lcm_pre.bsearch_index { |data|
        data[1] > cents
      }

      entry = [oct_reduced, cents, lcm, Math.log2(lcm), prime_fac, is_fundamental, weight]

      smooth_lcm_pre.insert(insert_idx, entry)
    end
    $GLO.puts "Calculating smooth height metric. Total: #{smooth_lcm_pre.size}"

    # Retrieve distance weighting to smooth out dissonance.
    # @param dist_cents [Float] Distance in cents
    distance_weight = Proc.new do |dist_cents|
      Math.exp(-0.5 * (dist_cents / (jnd_cents)) ** 2)
    end


    # Each element is a tuple of [lcm, heuristic_score]
    # @type [Array<Array(Rational, Float, Integer, Float, Array<Array(Integer, Integer)>)>]
    @smooth_height = smooth_lcm_pre.each_with_index.map{ |(ratio, cents, lcm, lcm_log2, prime_fac, is_fundamental, weight), idx|
      if idx % 1000 == 0
        $GLO.print "Calculating smooth height metric: #{idx} / #{smooth_lcm_pre.size}"
      end
      # Fundamental intervals should should have heuristic score of its own lcm
      next [ratio, cents, lcm, lcm_log2, prime_fac] if is_fundamental

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
        nei_ratio, nei_cents, nei_lcm, nei_lcm_log2, nei_prime_fac, nei_is_fund, nei_weight = smooth_lcm_pre[curr_idx]
        distance = nei_cents + 1200.0 * oct_offset - cents
        break if distance > 40

        # Only add neighbour if it improves the heuristic score.
        # The ear tends to 'autocorrect' intervals.
        next unless nei_lcm_log2 <= lcm_log2

        # if nei_ratio == 6/5r && ratio == 97/81r
        #   $GLO.print "nei distance: #{distance}, nei weight: #{nei_weight * distance_weight.(distance)}, self weight: #{weight}"
        # end

        # Decrease JND tolerance for simple intervals
        case nei_lcm
        when 1
          distance *= 5.0
        when 3
          distance *= 2
        when 5
          distance *= 1.5
        when 7
          distance *= 1
        end
        # normal distribution where standard deviation is JND.
        neighbours << [nei_lcm_log2, nei_weight * distance_weight.(distance), nei_ratio]
      end

      curr_idx = idx
      oct_offset = 0
      loop do # going backwards
        curr_idx -= 1
        if curr_idx < 0
          curr_idx = smooth_lcm_pre.size - 1
          oct_offset -= 1
        end
        nei_ratio, nei_cents, nei_lcm, nei_lcm_log2, nei_prime_fac, nei_is_fund, nei_weight = smooth_lcm_pre[curr_idx]
        distance = nei_cents + 1200.0 * oct_offset - cents
        break if distance < -40
        next unless nei_lcm_log2 <= lcm_log2
        case nei_lcm
        when 1
          distance *= 5.0
        when 3
          distance *= 2
        when 5
          distance *= 1.5
        when 7
          distance *= 1
        end
        neighbours << [nei_lcm_log2, nei_weight * distance_weight.(distance), nei_ratio]
      end

      # take weighted average

      # if ratio == 97/81r
      #   $GLO.puts "self: #{[lcm_log2, weight]}"
      #   $GLO.puts "neighbours: #{neighbours.sort { |a, b| b[1] <=> a[1] }}"
      # end

      total_weight, total_diss = neighbours.reduce([weight, lcm_log2 * weight]) { |acc, (lcm, w, _)|
        total_weight = acc[0] + w
        total_diss = acc[1] + lcm * w
        [total_weight, total_diss]
      }

      diss = total_diss / total_weight

      [ratio, cents, lcm, diss, prime_fac]
    }

    $GLO.puts "Saving smooth height to .csv"
    FileUtils.mkdir_p("#{$LIB_ROOT}/../../data")
    File.open("#{$LIB_ROOT}/../../data/smooth_height.csv", "w") do |f|
     f.puts "ratio,cents,lcm,diss,prime_fac"
      @smooth_height.each do |ratio, cents, lcm, diss, prime_fac|
        f.puts "#{ratio},#{cents},#{lcm},#{diss},\"#{prime_fac}\""
      end
    end
    File.open("#{$LIB_ROOT}/../../data/smooth_height_sort_diss.csv", "w") do |f|
     f.puts "ratio,cents,lcm,diss,prime_fac"
      @smooth_height.sort{_1[3] <=> _2[3]}.each do |ratio, cents, lcm, diss, prime_fac|
        f.puts "#{ratio},#{cents},#{lcm},#{diss},\"#{prime_fac}\""
      end
    end

    # Use ratio to lookup smooth height object.
    # @type [Hash<Rational, Array[Rational, Float, Integer, Float, Array<Array[Integer, Integer]>]>]
    @smooth_height_rat_lookup = @smooth_height.
    group_by { |ratio, cents, lcm, diss, prime_fac| ratio }.
    transform_values { |v|
      raise "Duplicate ratio in smooth height" if v.size > 1
      v[0]
    }

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
  # This is quite a bad heuristic score for chords - an attempt at polyadic harmonic entropy with only precomputed dyads,
  # instead of populating the entire n-adic lattice (there's too many of them).
  # Though, it works as long as there's only one 'complicated' interval within the chord, and the other intervals
  # can be expressed as simple intervals relative to the 'complicated' interval.
  # @param lcm_primes [Hash<Integer, Integer>] Prime factorized lcm hash of the entire chord.
  # @param power_2 [Float] How much to the final score powers of 2 should contribute.
  #                1.0 means full octave equivalence (octaves are infinitely consonant). 2.0 means zero octave equivalence.
  # @return [Float] The smooth lcm score.
  def poly_smooth_lcm(lcm_primes, power_2: 1.13)
    result = lcm_primes[2] * Math.log2(power_2)
    lcm_primes[2] = 0
    lcm = lcm_primes.reduce(1) { |acc, (base, pow)| acc * base ** pow }
    # @type [Array<Array(Rational, Float, Integer, Float, Array<Array(Integer, Integer)>)>]
    remaining = @smooth_height
    while lcm > 1
      max_score = 0
      max_score_interval = nil
      remaining = remaining.filter { |ratio, cents, lcm, diss, prime_fac|
        within = prime_fac.all? { |base, pow|
          lcm_primes[base] >= pow
        }
        next false if !within # overshoot
        # Greedy:
        # Maximize prime points while minimizing smooth lcm
        prime_points = prime_fac.reduce(0.0) { |acc, (base, pow)|
          acc + base ** pow
        }
        score = prime_points / diss
        if score > max_score
          max_score = score
          max_score_interval = [lcm, diss, prime_fac]
        end
        true
      }
      raise "Error! Could not find LCM match for #{lcm_primes}" if max_score_interval.nil?
      best_lcm, best_diss, best_prime_fac = max_score_interval
      result += best_diss
      best_prime_fac.each { |base, pow|
        lcm_primes[base] -= pow
        lcm /= base ** pow
      }
      # $GLO.print "Used best_lcm: #{best_lcm}"
    end
    result
  end

  # Get dyad height.
  # The current way this is implemented, the spread between positive and negative ratios
  # will always be the same no matter the interval. (Because of how octave displacements are handled).
  # TODO: Implement this properly using CB or some other method later.
  # @param ratio [Rational] The ratio of the dyad.
  def dyad_height(ratio, power_2: 1.13)
    lcm_primes = (ratio.numerator * ratio.denominator).prime_division.to_h
    lcm_primes.default = 0
    self.poly_smooth_lcm(lcm_primes, power_2: )
  end

  # Get chord complexity using recursive method. (Recursion helper)
  # At each iteration, the chord complexity will return the overall complexity score of the entire chord, and the
  # tonicity probability of each N-1 length subset of the chord.
  # @param ratios [Array<Rational>] The ratios in the chord. Must be sorted in increasing order & no duplicates.
  # @param power_2 [Float] How much octave equivalence. (1 = full octave equivalence, 2 = no octave equivalence)
  # @param lookup [Hash<Array<Rational>, Array()>]
  # @param debug [{:evals => Integer, :calls => Integer}] Debug info.
  #      `:evals`: Number of evaluations done (excluding lookups).
  #      `:calls`: Number of calls to this function (including lookups).
  def rec_nadic_complexity(ratios, power_2: 1.13, lookup: Hash.new, debug: {:evals => 0, :calls => 0})
    raise "rec_nadic_complexity must be passed at least 2 ratios" if ratios.size <= 1
    debug[:calls] += 1
    if lookup.has_key?(ratios)
      return lookup[ratios]
    end

    debug[:evals] += 1

    if ratios.size == 2
      # base case
      # evaluate the "tonicity" of the two notes using this heuristic:
      # If the positive ratio is twice as consonant as the negative ratio, then the bottom note (ratio[0])
      # is twice as tonicizable.
      pos_ratio = ratios[1] / ratios[0]
      pos_ratio_octs_disp = Math.log2(pos_ratio).floor
      neg_ratio = 1r / pos_ratio
      neg_ratio_octs_disp = Math.log2(neg_ratio).floor
      neg_ratio *= 2r ** (pos_ratio_octs_disp - neg_ratio_octs_disp)
      pos_height, neg_height = [pos_ratio, neg_ratio].map{self.dyad_height(_1, power_2:)}
      pos_tonicity, neg_tonicity = [pos_height, neg_height].map{2 ** (-_1)}
      tonicity_map = Hash.new # How 'tonic' each note is. Should add up to 1.
      tonicity_map[ratios[0]] = pos_tonicity / (pos_tonicity + neg_tonicity)
      tonicity_map[ratios[1]] = neg_tonicity / (pos_tonicity + neg_tonicity)
      lookup[ratios] = [pos_height, tonicity_map]
      debug[:evals] += 1
      return lookup[ratios]
    end

    # inductive case

    subset_tonicity_sum = 0.0

    # Evaluate all N-1 length subsets
    n_min_1 = ratios.combination(ratios.size - 1).each_with_index.map do |subset, idx|
      omitted = ratios[ratios.size - 1 - idx] # NOTE: This method of obtaining omitted note assumes combination is ordered.
      sub_eval = self.rec_nadic_complexity(subset, power_2: power_2, lookup:, debug:)
      subset_tonicity_sum += 2 ** (-sub_eval[0])
      [subset, omitted, sub_eval]
    end

    final_chord_cplx = 0.0
    new_tonicity_map = Hash.new { |h,k| h[k] = 0.0 }
    n_min_1.each do |subset, omitted, (subset_cplx, tonicity_map)|
      # Try out each probable tonic in all N-1 length subsets:
      subset_tonics_cplx_sum = 0.0
      tonicity_map.each do |tonic, tonicity|
        # represents relative tonicity of this current choice of tonic within the context of this subset.
        # For now, we define the tonicity of each possible tonic to be note_tonicity * 2^(-total_chord_height)
        # TODO: This is a heuristic that should be improved later.
        rel_tonicity = 2 ** (-subset_cplx) * tonicity
        new_tonicity_map[tonic] += rel_tonicity

        # evaluate the complexity of the omitted note with respect to this tonic
        om_dyad = omitted > tonic ? [tonic, omitted] : [omitted, tonic]
        om_height, om_tonicity_map = self.rec_nadic_complexity(om_dyad, power_2: power_2, lookup:, debug:)
        # the probability of hearing these notes as tonic is dependent on hearing the 'tonic' note as tonic within
        # the context of the subset => multiplication of probabilities
        new_tonicity_map[tonic] += om_tonicity_map[tonic] * rel_tonicity
        new_tonicity_map[omitted] += om_tonicity_map[omitted] * rel_tonicity

        # the complexity of the chord is scaled by the probability of hearing this note as tonic.
        # abs_tonicity is the probility of hearing this current tonic within the context of the subset,
        # amongst all subsets.
        abs_tonicity = rel_tonicity / subset_tonicity_sum
        subset_tonics_cplx_sum += abs_tonicity * om_height
      end
      final_chord_cplx += (subset_cplx + subset_tonics_cplx_sum) / n_min_1.size
    end

    # normalize the new tonicity map so the tonicity probility sums to 1.
    new_tonicity_sum = new_tonicity_map.values.sum
    new_tonicity_map.transform_values!{|v| v / new_tonicity_sum}

    lookup[ratios] = [final_chord_cplx, new_tonicity_map]
    return lookup[ratios]
  end
end

# Access calc methods using this Singleton.
$CALC = CalcSingleton.new
