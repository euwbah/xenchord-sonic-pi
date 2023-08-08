# Data classes (all immutable)
# Run order: after polyfills.rb

# Represents pitch/intervals
# The + - operators perform interval addition/subtraction in exp space
# The * operator stacks the interval n times
class Monzo
  include Comparable

  attr_reader :ratio, :primes, :prime_limit # Rational numeric # Hash of { prime_base => power }. Power defauls to 0 for unassigned bases. # stores the max prime (useful for gcf calculations)

  # p can either be a list of numbers representing powers of primes 2, 3, 5, ...
  # or a single positive Rational/float
  #
  # Non-integer powers will be truncated to integers.
  def initialize(*p)
    p = p[0].to_a if p[0].is_a? Enumerable and !p[0].is_a? Hash

    if p.size == 0
      @ratio = 1/1r
      @primes = {}
      @prime_limit = 2
    elsif p[0].is_a? Monzo
      c = p[0]
      @ratio = c.ratio
      @primes = c.primes
      @prime_limit = c.prime_limit
    elsif p[0].is_a? Numeric and p[0] > 0 and p.size == 1
      # p[0] is a ratio
      @ratio = p[0].is_a?(Rational) ? p[0] : p[0].to_s.to_r
      n, d = [@ratio.numerator, @ratio.denominator].map { Prime.prime_division _1 }
      @primes = Hash.new(0)
      n.each { |base, pow| @primes[base] = pow }
      d.each { |base, pow| @primes[base] -= pow }
      @prime_limit = @primes.keys.max
    elsif p[0].is_a? Hash and p.size == 1
      # p[0] is another Monzo's @primes instance var
      @primes = p[0]
      @ratio = 1/1r
      @primes.each { |base, pow| @ratio *= base**pow }
      @prime_limit = @primes.keys.max
    else
      # p is an array of prime powers
      @primes = Hash.new(0)
      @ratio = 1/1r
      p.each_with_index do |pow, idx|
        @primes[$PRIMES[idx]] = pow.to_i
        @ratio *= $PRIMES[idx]**pow.to_i
      end
      @prime_limit = @primes.keys.max
    end
  end

  def ==(other)
    if other.is_a? Monzo
      @ratio == other.ratio
    elsif other.is_a? Rational
      @ratio == other
    elsif other.is_a? Numeric
      @ratio == other.to_s.to_r
    else
      raise "Unsupported type for comparison: comparing Monzo with #{other.class}"
    end
  end

  def <=>(other)
    if other.is_a? Monzo
      @ratio <=> other.ratio
    elsif other.is_a? Rational
      @ratio <=> other
    elsif other.is_a? Numeric
      @ratio <=> other.to_s.to_r
    else
      raise "Unsupported type for comparison: comparing Monzo with #{other.class}"
    end
  end

  # Interval addition == Ratio multiplication
  def +(other)
    case other
    when Monzo
      Monzo.new(other.ratio * @ratio)
    when Rational
      Monzo.new(other * @ratio)
    when Numeric
      Monzo.new(other.to_s.to_r * @ratio)
    else
      raise "Invalid type for interval addition"
    end
  end

  def -(other)
    case other
    when Monzo
      Monzo.new(@ratio / other.ratio)
    when Rational
      Monzo.new(@ratio / other)
    when Numeric
      Monzo.new(@ratio / other.to_s.to_r)
    else
      raise "Invalid type for interval addition"
    end
  end

  def -@
    Monzo.new(1 / @ratio)
  end

  def +@
    self
  end

  # Interval multiplication/stacking == Ratio powers
  def *(other)
    raise "Monzo#* expects a Numeric operand. Received #{other.class} instead" unless other.is_a? Numeric

    Monzo.new(ratio**other.to_i)
  end

  # Infix operator for GCF of 2 monzos.
  # can think of this operator as bitwise and of the frobenius space (lol)
  # @other [Monzo] Another monzo
  # @return [Monzo] The GCF as a Monzo, represented as the minimum power of each prime.
  def &(other)
    gcf(other)
  end

  # Infix operator for LCM of 2 monzos.
  # @other [Monzo] Another monzo
  # @return [Monzo] The LCM as a monzo (Monzo#ratio will equal the LCM)
  def |(other)
    lcm(other)
  end

  # @param others [Monzo] One or more monzos.
  # @return [Monzo] The GCF as a Monzo, represented as the minimum power of each prime.
  def gcf(*others)
    others = others[0] if others[0].is_a? Enumerable
    Monzo.gcf([self] + others)
  end

  # @param others [Monzo] One or more monzos.
  # @return [Monzo] The LCM as a monzo (Monzo.ratio will equal the LCM)
  def lcm(*others)
    others = others[0] if others[0].is_a? Enumerable
    Monzo.lcm([self] + others)
  end

  def within(lower_lim, upper_lim)
    lower_lim = lower_lim.ratio if lower_lim.is_a? Monzo
    upper_lim = upper_lim.ratio if upper_lim.is_a? Monzo
    off = 0 # offset to apply in octaves
    if @ratio / lower_lim < 1
      off = -Math.log2(@ratio / lower_lim).floor
    elsif @ratio / upper_lim > 1
      off = -Math.log2(@ratio / upper_lim).ceil
    end
    self + Monzo.new(off, 0)
  end

  # Get max prime limit of several monzos
  def max_limit(*others)
    others = others[0] if others[0].is_a? Enumerable
    return @prime_limit if others.nil? || (others.size == 0)

    [@prime_limit, *others.map(&:prime_limit)].max
  end

  # Convert to log2 space (counting number of octaves)
  # Assumes 1/1 is 0 octaves.
  def log2
    @log2_cache = Math.log2(@ratio) unless defined?(@log2_cache)
    @log2_cache
  end
  alias octaves log2

  def to_r
    @ratio
  end

  def to_monzo_s
    m = @primes.map { |k, v| "#{k}^#{v}" }.join(" * ")
    "[#{m}>"
  end

  def to_s
    "#{@ratio} #{to_monzo_s}"
  end

  def to_json(*_args)
    @primes.to_json
  end

  def inspect
    to_s
  end

  # @param monzos [Monzo] One or more monzos.
  # @return [Monzo] The GCF as a Monzo, represented as the minimum power of each prime.
  def self.gcf(*monzos)
    monzos = monzos[0] if monzos[0].is_a? Enumerable
    incl_primes = monzos
                  .map { _1.primes.keys }
                  .reduce([]) { |acc, elem| acc | elem }
    # puts "primes included: #{incl_primes}"
    gcf_primes = incl_primes.map do |p|
      [p, monzos.map { _1.primes[p] }.min]
    end.to_h
    # puts gcf_primes
    Monzo.new(gcf_primes)
  end

  # @param monzos [Monzo] One or more monzos.
  # @return [Monzo] The LCM as a monzo (Monzo#ratio will equal the LCM)
  def self.lcm(*monzos)
    Monzo.new(Monzo.lcm_primes(*monzos))
  end

  # @param monzos [Monzo] One or more monzos.
  # @return [Hash<Integer, Integer>] The LCM as a hash of primes and their powers.
  #     This hash can be passed to Monzo.new to create a monzo with the LCM fleshed out.
  def self.lcm_primes(*monzos)
    monzos = monzos[0] if monzos[0].is_a? Enumerable
    incl_primes = monzos
                  .map { _1.primes.keys }
                  .reduce([]) { |acc, elem| acc | elem }
    hash = incl_primes.map do |p|
      [p, monzos.map { _1.primes[p] }.max]
    end.to_h
    hash.default = 0 # set default power if base not present to 0
    hash
  end
end

# Shorthand fn to create Monzo instance
# NOTE: In Sonic Pi, referencing global functions like these inside classes requires
# explicitly using the $GLO.<fn_name> prefix as defined in prelude_for_livecoding.rb.
define :m do |*p|
  Monzo.new(*p)
end

# Represents multiple numerics as a ratio of integers relative to
# each other.
# Do not repeat the same note twice (certain calculation features
# depend on the uniqueness of each note).
class Chord
  attr_reader :monzos, :abs_ratios, :monzos_sorted, :origin, :fund
  attr_reader :ratio_monzos, :ratio, :ratio_set, :centroid

  def initialize(*p)
    p = p[0].to_a if p[0].is_a? Enumerable

    if p[0].is_a? Chord
      cr = p[0] # copy constructor
      @monzos = cr.monzos
      @abs_ratios = cr.abs_ratios
      @monzos_sorted = cr.monzos_sorted
      @origin = cr.origin
      @fund = cr.fund
      @ratio_monzos = cr.ratio_monzos
      @ratio = cr.ratio
      @ratio_set = cr.ratio_set
      @centroid = cr.centroid
    else
      # Absolute values

      # The absolute notes.
      # @type [Array<Monzo>]
      @monzos = p.map { Monzo.new _1 }
      # The absolute ratios of the chord.
      # @type [Array<Rational>]
      @abs_ratios = @monzos.map(&:ratio)
      # The absolute notes in ascending order.
      # @type [Array<Monzo>]
      @monzos_sorted = @monzos.sort
      # The first Monzo in `Chord#monzos`
      # @type [Monzo]
      @origin = @monzos[0]
      # The absolute note that represents '1' in the integer ratio Chord#ratio.
      # @type [Monzo]
      @fund = Monzo.gcf(monzos)

      # Relative values

      # Monzo form of `Chord#ratio`. Relative to Chord#fund.
      # @type [Array<Monzo>]
      @ratio_monzos = @monzos.map { _1 - @fund }

      # Most reduced integer ratio.
      # @type [Array<Integer>]
      @ratio = @ratio_monzos.map do
        $GLO.puts("ERROR: Chord has non-integer: #{_1.ratio}") if _1.ratio % 1 != 0
        _1.ratio.to_i
      end
      # Set of relative ratios.
      # @type [Set<Integer>]
      @ratio_set = Set.new(ratio)

      # Average of frequencies in log2 units (number of octaves) relative to @origin.
      # @type [Float]
      @centroid = Math.log2(@ratio.reduce(1r) { |acc, r| acc * r }) / @monzos.size - Math.log2(@ratio[0])
    end
  end

  # Returns true if the relative ratios between two Chords are the same
  # Order and absolute origin can be different.
  def same_voicing?(other)
    @ratio_set == other.ratio_set
  end

  # Returns new Chord with octave shift such that the absolute centroid
  # of the new Chord is as close as possible to the specified middle
  #
  # mid: <Monzo | Numeric>
  #   desired centroid middle location of voicing.
  def oct_match(mid)
    mid_octs = if mid.is_a? Monzo
                 mid.log2
               else
                 Math.log2(mid)
               end
    abs_centroid = @centroid + @origin.log2
    oct_offset = (mid_octs - abs_centroid).round
    Chord.new(self).shift_origin(Monzo.new(oct_offset, 0))
  end

  # Returns a new Chord with the lowest note shifted to the specified note.
  # NOTE: The lowest note may not necessarily be Chord#origin.
  # @param note [Monzo | Numeric] The note to shift to.
  def root(note)
    case note
    when Monzo, Rational
      Chord.new(self).shift_origin(- @monzos_sorted[0] + note)
    when Numeric
      Chord.new(self).shift_origin(Monzo.new(note.to_s.to_r) - @monzos_sorted[0])
    else
      raise "Invalid type"
    end
  end

  def to_s
    @ratio.join(":") + " @ " + origin.to_s
  end

  def inspect
    to_s
  end

  def play(**kwargs)
    $GLO.puts "@monzos: #{@monzos}"
    $GLO.p(*@monzos, **kwargs)
  end
  alias p play

  # Returns a new Chord transposed up by given ratio/monzo.
  def +(other)
    clone = Chord.new(self)
    clone.shift_origin(other)
  end

  # Returns a new Chord transposed down by given ratio/monzo.
  def -(other)
    other = Monzo.new(other) unless other.is_a? Monzo
    other = -other
    self + other
  end

  # Alias for Chord#root
  def /(note)
    self.root(note)
  end

  # Returns a new Chord concatenated with another Chord or Monzo
  # Duplicates will be removed.
  def &(other)
    case other
    when Chord
      Chord.new([@monzos + other.monzos].to_set.to_a)
    when Monzo
      Chord.new([@monzos + [other]].to_set.to_a)
    when Rational
      Chord.new([@monzos + [Monzo.new(other)]].to_set.to_a)
    when Numeric
      Chord.new([@monzos + [Monzo.new(other.to_s.to_r)]].to_set.to_a)
    else
      raise "Expected Chord | Monzo | Numeric, got #{other.class} instead."
    end
  end

  def size
    @ratio.size
  end
  alias length size

  def [](i)
    @monzos[i]
  end

  # Get the smallest interval between two adjacent notes
  def min_interval
    @monzos_sorted.each_cons(2).map { _2 - _1 }.min
  end

  # Get the largest interval between two adjacent notes
  def max_interval
    @monzos_sorted.each_cons(2).map { _2 - _1 }.max
  end

  # Get lowest common multiple of the overall chord.
  # This LCM is calculated using the reduced integer multiratio.
  def lcm
    Monzo.lcm(@ratio_monzos).to_r
  end

  def lcm_primes
    Monzo.lcm_primes(@ratio_monzos)
  end

  # @param [Integer] length
  # @return [Array<Chord>] all possible combinations of the Chord of given length
  def combination(length)
    @ratio.combination(length).map { Chord.new(_1) }
  end

  protected

  # Shift origin by a monzo
  # This function mutates the instance! Only call this after cloning.
  def shift_origin(interval)
    interval = Monzo.new(interval) unless interval.is_a? Monzo
    @origin += interval
    @fund += interval
    @monzos.map! { _1 + interval }
    @monzos_sorted.map! {_1 + interval }
    @abs_ratios.map! { _1 * interval.ratio }
    self
  end
end

# Represents collection of unique pitches within the interval [1/1, 2/1)
class Harmony
  attr_reader :freqs

  def initialize(*freqs)
    @freqs = freqs
  end

  def size
    @freqs.size
  end

  def move_note; end
end
