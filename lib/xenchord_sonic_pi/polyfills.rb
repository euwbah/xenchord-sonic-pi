# Polyfills (Run order: 1/3)
$GLO = self

module Samplable
  # For some weird reason, Sonic Pi's Array.sample doesn't seem to give back multiple results
  # so here it is...
  # Compatible with the SonicPi global context's random seed & source
  def sample(num = 1)
    if num == 1
      self[$GLO.rand_i(size)]
    else
      shuffle.take(num)
    end
  end
end

Array.prepend(Samplable)

module InThreadPrint
  def print(*args)
    in_thread do
      $GLO.puts(*args)
    end
  end
end

$GLO.class.prepend(InThreadPrint)
