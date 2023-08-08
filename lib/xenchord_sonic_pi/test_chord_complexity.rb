chords = [
  Chord.new(4,5,6),
  Chord.new(10,12,15),
  Chord.new(6,7,9),
  Chord.new(16, 20, 24, 30, 36, 45),
  Chord.new(15, 19, 23, 29, 35, 44),
  Chord.new(20, 24, 30, 36, 45, 54)
].map{_1 / (1/1r)}

res = chords.map do |c|
  lookup = Hash.new
  debug = {:evals => 0, :calls => 0}
  cplx, tonic_probs = $CALC.rec_nadic_complexity(c.abs_ratios, lookup:, debug:)
  puts "#{c}: cplx: #{cplx}, tonic_probs: #{tonic_probs}"
  lookup.filter { _1 == 6/5r || _1.include?(6/5r)}.each {
    ##| puts "#{_1}: #{_2}"
  }
  puts debug
  [c, cplx, tonic_probs]
end

use_synth :tri

res.sort {_1[1] <=> _2[1]}.each do |c, cplx, probs|
  c.play sustain: 1, panspr: 0.4, amp: 0.5
  puts "#{c.ratio}: #{cplx}, #{probs}"
  sleep 2
end
