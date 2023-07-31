live_loop :test do
  stop
  voicing = [
    MultiRatio.new(10, 12, 13, 15, 18),
    MultiRatio.new(8, 10, 12, 15, 18)
  ][look % 8 / 4]
  chd = (voicing + [1/1r, 4/3r, 8/9r][look % 24 / 8]).oct_match(1/1r)
  chd.play
  sleep 1
  tick
end

live_loop :a do
  with_fx :tremolo, phase: 0.125, wave: 0, depth: Math.cos(vt) * 0.1 + 0.9, depth_slide: 4 do
    with_fx :echo, phase: 0.375, decay: 5, mix: 0.5 do
      use_synth :dsaw
      mr = [
        MultiRatio.new(10, 12, 15, 18),
        MultiRatio.new(6, 7, 9, 11) + 5/4r,
        MultiRatio.new(8, 10, 12, 15),
        MultiRatio.new(8, 10, 12, 15, 18)
      ][look % 4]
      mr -= 2/3r if look % 8 == 0
      mr = mr.oct_match(9/8r)
      len = [5, 3, 6, 2][look % 4]
      mr.play cutoff: [90 - tick(:fade) * 5, 0].max, detune: 0.05, attack: 1, sustain: len - 1, release: 0, amp: 0.5
      use_synth :tb303
      bass = mr.monzos[0] - 2/1r
      bass -= 6/5r if look % 8 == 3
      bass += 5/4r if look % 8 == 7
      bass -= 5/4r if look % 8 == 4
      # #| p bass, amp: 0.24, sustain: len - 1, cutoff: 51
      sleep len
      tick
    end
  end
end

live_loop :drs do
  with_fx :lpf, cutoff: 63, cutoff_slide: 16 do |_lpf_drs|
    with_fx :echo, decay: 2, phase: 0.125, mix: 0.1 do |_echo_drs|
      use_bpm 60
      with_random_seed 53 do
        32.times do |k|
          smp = rand
          if false
            onset = [0, 3].choose
            4.times do
              sample(:loop_amen, release: 0.125, sustain: 0, onset:)
              o "/drums", onset
              sleep 1.0 / 16.0
            end
          elsif smp < 0.85
            onset = [0, 1, 2, 1, 4, 3, 2, 5][k % 8]
            if rand < 0.3 or k % 4 == 0
              sample :loop_amen, release: 0.3, sustain: 0,
                                 onset:
            end
            o "/drums", onset
            sleep 0.25
          else
            2.times do |i|
              onset = [0, 1, 2, 1, 4, 3, 2, 5][(k + i) % 8]
              sample(:loop_amen, release: 0.125, sustain: 0,
                                 onset:)
              o "/drums", onset
              sleep 0.125
            end
          end
        end
      end
    end
  end
end
