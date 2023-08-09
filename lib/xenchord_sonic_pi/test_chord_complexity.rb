chords = [
  [Chord.new(4,5,6), "Maj triad (4:5:6)"],
  [Chord.new(41,51,61),"Maj (4:5:6)[+0.1] (61-limit)"],
  [Chord.new(81,101,121),"Maj (4:5:6)[+0.05] (101-lim)"],
  [Chord.new(121,151,181),"Maj (4:5:6)[+1/30] (181-lim)"],
  [Chord.new(401,501,601),"Maj (4:5:6)[+1/100] (601-lim)"],
  [Chord.new(4001,5001,6001),"Maj (4:5:6)[+1/1000] (4001-lim)"],
  [Chord.new(10,12,15),"Min triad (5-lim)"],
  [Chord.new(6,7,9),"Sub minor triad (7-lim)"],
  [Chord.new(16,19,24),"Min triad (19-lim)"],
  [Chord.new(64,76,96,114,144,171),"extended min11 (19-lim)"],
  [Chord.new(16,20,24,30,36,45),"Maj9#11 (5-lim)"],
  [Chord.new(15,19,23,29,35,44),"(Maj9#11)[-1] (29-lim) - higher complexity than prev chord despite lower partials"],
  [Chord.new(20,24,30,36,45,54),"min11 (5-lim)"],
  [Chord.new(5,6,7,9),"m7b5 (7-lim) - rootless otonal ninth"],
  [Chord.new(4,5,6,7,9),"!9 (7-lim) - otonal harmonic ninth, lower complexity than prev chord"],
  [Chord.new(1/4r, 1/5r, 1/6r, 1/7r, 1/9r),"1/(!9) (7-lim) - utonal harmonic ninth, higher complexity than prev"],
  [Chord.new(12,15,16,20),"Maj7 2nd inversion (5-lim)"],
  [Chord.new(12,15,16,18),"Maj add4 / rootless closed maj 9 (5-lim)"],
  [Chord.new(45,60,64,80),"m7b5 add11 (5-lim)"],
  [Chord.new(45,60,80),"3 quartals (3-lim)"],
  [Chord.new(45,64,80),"m7b5 no3 (5-lim), higher complexity than m7b5add11"],
  [Chord.new(1/1r, 6/5r, 5/4r, 3/2r),"maj add min3 (5-lim), noticeable complexity increase from maj triad and min triad"],
].map{[_1[0] / (1/1r), _1[1]]}

res = chords.map do |c, desc|
  lookup = Hash.new
  debug = {:evals => 0, :calls => 0}
  cplx, tonic_probs = $CALC.rec_nadic_complexity(c.monzos_sorted, lookup:, debug:)
  puts desc
  puts "#{c}: cplx: #{cplx}, tonic_probs: #{tonic_probs}"
  lookup.filter { _1 == 6/5r || _1.include?(6/5r)}.each {
    ##| puts "#{_1}: #{_2}"
  }
  puts debug
  [c, cplx, tonic_probs]
end

use_synth :tri

#res.sort! {_1[1] <=> _2[1]}

res.each do |c, cplx, probs|
  c.play sustain: 1, panspr: 0.4, amp: 0.5
  puts "#{c.ratio}: #{cplx}, #{probs}"
  sleep 2
end
