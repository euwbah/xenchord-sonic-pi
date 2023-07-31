# Data classes (all immutable)
# Run order: 3/4

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
        @primes[PRIMES[idx]] = pow.to_i
        @ratio *= PRIMES[idx]**pow.to_i
      end
      @prime_limit = @primes.keys.max
    end
  end

  def ==(other)
    @ratio == other.ratio
  end

  def <=>(other)
    @ratio <=> other.ratio
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
    raise "Invalid type for interval stacking" unless other.is_a? Numeric

    Monzo.new(ratio**other.to_i)
  end

  # Infix operator for GCF of 2 monzos.
  # can think of this operator as bitwise and of the frobenius space (lol)
  def &(other)
    gcf(other)
  end

  # Infix operator for LCM of 2 monzos.
  def |(other)
    lcm(other)
  end

  # Greatest common factor between N other monzos
  # The GCF would be the smallest power of each prime.
  def gcf(*others)
    others = others[0] if others[0].is_a? Enumerable
    Monzo.gcf([self] + others)
  end

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

  def self.lcm(*monzos)
    monzos = monzos[0] if monzos[0].is_a? Enumerable
    incl_primes = monzos
                  .map { _1.primes.keys }
                  .reduce([]) { |acc, elem| acc | elem }
    lcm_primes = incl_primes.map do |p|
      [p, monzos.map { _1.primes[p] }.max]
    end.to_h
    Monzo.new(lcm_primes)
  end
end

# Shorthand fn to create Monzo instance
# NOTE: In Sonic Pi, referencing global functions like these inside classes requires
# explicitly using the $GLO.<fn_name> prefix as defined in prelude_for_livecoding.rb.
def m(*p)
  Monzo.new(*p)
end

# Represents multiple numerics as a ratio of integers relative to
# each other.
class MultiRatio
  # Stores the integer ratio (ordering is preserved) as a list of Integers
  # (preserves the relative ratio between numbers, but not the absolute value)
  attr_reader :ratio
  attr_reader :ratio_monzos, :centroid, :ratio_set, :monzos # Same as relative intervals as @ratio but in Monzo form # Average of frequencies in log2 units (num. octaves) relative to @origin. # Same as @ratio, but as a Hash Set

  # Stores the original absolute input value of the first value
  attr_reader :origin

  # stores the absolute monzo of where the relative 1/1 of @ratio is.
  # @monzos[i] = fund + @ratio[i]
  attr_reader :fund # original absolute values of the ratio in monzo form

  def initialize(*p)
    p = p[0].to_a if p[0].is_a? Enumerable

    if p[0].is_a? MultiRatio
      cr = p[0]
      @ratio = cr.ratio
      @ratio_set = cr.ratio_set
      @origin = cr.origin
      @fund = cr.fund
      @monzos = cr.monzos
      @ratio_monzos = cr.ratio_monzos
      @centroid = cr.centroid
    else
      # Absolute values
      @monzos = p.map { Monzo.new _1 }
      @origin = @monzos[0]
      @fund = Monzo.gcf(monzos)

      # Relative values
      @ratio_monzos = @monzos.map { _1 - @fund }
      @ratio = @ratio_monzos.map do
        $GLO.puts("WARNING: MultiRatio has non-integer: #{_1.ratio}") if _1.ratio % 1 != 0
        _1.ratio.to_i
      end
      @ratio_set = Set.new(ratio)
      @centroid = Math.log2(@ratio.reduce(1r) { |acc, r| acc * r }) / @monzos.size - Math.log2(@ratio[0])
    end
  end

  # Returns true if the relative ratios between two MultiRatios are the same
  # Order and absolute origin can be different.
  def same_voicing?(other)
    @ratio_set == other.ratio_set
  end

  # Returns new MultiRatio with octave shift such that the absolute centroid
  # of the new MultiRatio is as close as possible to the specified middle
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
    MultiRatio.new(self).shift_origin(Monzo.new(oct_offset, 0))
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

  # Change origin while keeping constant structure
  def +(other)
    clone = MultiRatio.new(self)
    clone.shift_origin(other)
  end

  def -(other)
    other = Monzo.new(other) unless other.is_a? Monzo
    other = -other
    self + other
  end

  protected

  # Shift origin by a monzo
  # This function mutates the instance!!
  def shift_origin(interval)
    interval = Monzo.new(interval) unless interval.is_a? Monzo
    @origin += interval
    @fund += interval
    @monzos.map! { _1 + interval }
    self
  end
end

mr = MultiRatio.new(5/4r, 19/17r)
mr3 = MultiRatio.new(1, 5/4r, 3/2r)

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
