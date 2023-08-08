# HELPER METHODS
# Run order: after polyfills.rb and dataclasses.rb

require 'json'
require 'set'

define :tihai_search do |notes_min, notes_max, rest_min, rest_max, target_matra|

end

# send osc
define :o do |*args|
  osc_send($IP_ADDR, 9000, *args)
end

# Play a monzo or monzo-constructor parameter
# Accepts var arguments of monzos, followed by play kwargs
define :p do |*args, **kwargs|
  return if args.size == 0
  chd_monzos = args.map { |a|
    Monzo.new(a)
  }
  chd = chd_monzos.map{ |a|
    hz = a.ratio * $F0_HZ
    o('/note', a.primes.to_json, a.ratio * $F0_HZ)
    hz_to_midi hz
  }.to_a
  if kwargs.has_key?(:panspr) && chd.size > 1
    amp = kwargs.fetch(:amp, 1.0).to_f / chd.size
    pan, panspr = kwargs.fetch(:pan, 0.0), kwargs[:panspr].to_f
    pans = (0...chd.size).map {
      x = (pan - panspr + 2 * panspr *_1 / (chd.size - 1))
      [[x, -1].max, 1].min
    }
    kwargs.delete(:pan)
    kwargs.delete(:panspr)
    kwargs.delete(:amp)
    chd.each_with_index do |note, idx|
      # generates a zigzag sequence from the center out
      # e.g. if chd.size = 5, generates: 2, 1, 3, 0, 4
      i = chd.size / 2 + ((idx + 1) / 2) * (1 - 2 * (idx % 2))
      play note, pan: pans[i], amp: amp, **kwargs
    end
  else
    play_chord chd, **kwargs
  end
end

# euclidean cycle with additive numerical result
# size: size of array
# args: var args in groups of 3, each group representing one euclidean rhythm:
#   (number accents, rotation, number to add)
# returns a ring of numbers.
define :euc do |size, *args|
  assert args.size % 3 == 0, "euc must have additional arguments in multiples of 3"
  l = args.each_slice(3).map {|accc, rot, num|
    [spread(accc, size, rotate: rot), num]
  }.reduce([0]*size) {|accc, (e_bools, num) |
    puts e_bools, num
    (0...size).map{
      accc[_1] + (e_bools[_1] ? num : 0)
    }.to_a
  }
  ring(*l)
end

# Input a list of Rationals that represent pitch classes modulo
# the octave. Input should be normalized to appear within 1/1 to 2/1.
#
# The octave equivalence is applied based on $ISO_OCT_EQV_BOUNDS.
#
# rats:
#   input list of Rationals in the interval [1, 2)
# max_arith_diff:
#   The max interval increment in any arith sequence must be at most this interval
#   E.g. if max diff is 3/1r, 5:9:13 will be part of the output, but 1:5:9:13 will not.
#   Reason being, the combination concordance effect seems weaker the further apart
#   consecutive isoharmonics are.
#
# This algo returns all isoharmonic subsets of length 3 and above.
#
# Returns a Hash:
#   key: length of the isoharmonic seq
#   value: list of isoharmonic seqs with given length presented as:
#          [incl_idxs, arith_seq, rem_terms]
#          (See comment below)
#
# See: https://www.facebook.com/groups/497105067092502/posts/2854653928004259/?comment_id=2854699357999716&reply_comment_id=2854871454649173
define :isoharm_search_full do |rats, max_arith_diff=2r|
  bel, abv = *$ISO_OCT_EQV_BOUNDS

  # Each element contains list of [rat, idx] pairs that correspond
  # to octave-equivalent notes of the input ratio at given idx
  rats_idx_pair = rats.map.with_index{ |r, idx|
    (bel..abv).map{[r*2**_1, idx]}.to_a
  }.to_a

  # collect all usable octaves of the pitch classes in the form
  # [ratio, index of original ratio],
  # and sort in increasing order. Flattened so that [rat, idx] pairs are all in one list.
  rats_sorted = rats_idx_pair.
    flatten(1).
    sort {_1[0] <=> _2[0]}

  # search list. each element in the list is of the form:
  # [[incl_idxs], [arith_seq], [remaining_search_terms]]
  # incl_idxs: The list of original rats' indices already included in the arith_seq
  #
  # arith_seq: The arithmetic sequence as a list of [ratio, idx] (elements from rats_sorted).
  #            This should always be in ascending order.
  #       NOTE The algo simply uses the last 2 elements to calculate the next term in the seq to look for.
  #
  # remaining_search_terms: Sorted sublist of a copy of rats_sorted_indexed that excludes
  #                         ratios that are already included in the arith_seq
  search = []

  #
  # populate search list with all pairs first.
  #

  oct_idx_pairs = (0...rats_idx_pair[0].size).to_a.repeated_permutation(2).to_a
  (0...rats.size).to_a.combination(2) { |r_idx1, r_idx2|
    rem_terms = rats_sorted.filter { |_, i| i != r_idx1 and i != r_idx2 }
    oct_idx_pairs.each{ |o1, o2|
      incl_idxs = [r_idx1, r_idx2]
      arith_seq = [rats_idx_pair[r_idx1][o1], rats_idx_pair[r_idx2][o2]].sort
      if arith_seq[1][0] / arith_seq[0][0] < max_arith_diff
        search.push [incl_idxs, arith_seq, rem_terms]
      end
    }
  }

  # Return hash
  # keys: length of isoharmonic seq
  # value: list of terminal isharmonic sequences at given length.
  ret = Hash.new{ |h, k| h[k] = [] }

  # This is essentially a BFS.
  while true
    no_op = true
    new_search = []
    search.each { |incl_idxs, arith_seq, rem_terms|
      # find first index of rem_terms that matches the succ we're looking for
      last, seclast = arith_seq[-1][0], arith_seq[-2][0]
      succ = last + (last - seclast)
      term_idx = rem_terms.bsearch_index { _1[0] >= succ }
      if term_idx.nil? or rem_terms[term_idx][0] != succ
        # This search branch has reached the end.
        if arith_seq.size > 2
          # store all non-trivial isoharm seq (len 3 or more)
          # to output
          ret[arith_seq.size].push([incl_idxs, arith_seq, rem_terms])
        end
        next
      end

      no_op = false

      # there should not be multiple matches given the same successive term
      # unless the input is bad and contains octave intervals.
      # For the sake of supporting more general inputs, implement it like this.
      while term_idx < rem_terms.size and rem_terms[term_idx][0] == succ
        incl_r, incl_i = rem_terms[term_idx]
        new_rem = rem_terms.filter { |rem_rat, rat_idx| rat_idx != incl_i }
        new_search.push [incl_idxs + [incl_i], arith_seq + [[incl_r, incl_i]], new_rem]
        term_idx += 1
      end
    }
    break if no_op

    search = new_search
  end

  return ret
end

# Same as isoharm_search_full, but returns MultiRatios,
# removes duplicate voicings at different octaves.
#
define :isoharm_search do |rats, max_arith_diff=2r|
  h = isoharm_search_full(rats, max_arith_diff)
  # key is the length of isoharm
  isoharms = h.map{ |k,v| [
      k,
      v.map{ |_, arith, _| arith }
  ]}.to_h
end

# Alternate strategy proposed by Mike Battaglia:
# https://www.facebook.com/groups/497105067092502/posts/2854653928004259/?comment_id=2856057251197260
#
# Makes use of the linearity property of an isoharmonic sequence.
# Generates all pairs of ratios that are less than max_arith_diff apart,
# From all pairs of ratios, search for the longest isoharm sequence while fixing certain input notes.
#
# rats:
#   input list of Rationals in the interval [1, 2)
#
# max_arith_diff:
#   The max interval increment in any arith sequence must be at most this interval
#   E.g. if max diff is 3/1r, 5:9:13 will be part of the output, but 1:5:9:13 will not.
#   Motivated by a hypothesis that the combination concordance effect seems weaker the
#   further apart
#   consecutive isoharmonics are.
#
# fix:
#  list of 0-based indices of input notes to fix without changing its octave.
#
# This algo a list of the longest isoharmonic subsequences that fulfil the above criteria.
#
# Only returns the longest isoharmonic series that fulfils the notes to fix.
define :isoharm_search_2 do |rats, max_arith_diff=2r, fix=[]|
  bel, abv = *$ISO_OCT_EQV_BOUNDS

  # List of lists.
  # Each ratio in `rats` gets turned into a list of [rat, idx, octave offset] triples.
  # rat: ratio with octave offset applied
  # idx: index of original ratio in `rats` input list
  # octave offset: number of octaves offset applied to original ratio.
  notes_octs = rats.map.with_index{ |r, idx|
    (bel..abv).map{[r*2**_1, idx, _1]}.to_a
  }.to_a

  # collect all usable octaves of the pitch classes in the form
  # [ratio, index of original ratio],
  # and sort in increasing order. Flattened so that [rat, idx] pairs are all in one list.
  notes_sorted = notes_octs.
    flatten(1).
    sort {_1[0] <=> _2[0]}

  # search list. each element in the list is of the form:
  # [[incl_idxs], [arith_seq], [remaining_search_terms]]
  # incl_idxs: The list of original rats' indices already included in the arith_seq
  #
  # arith_seq: The arithmetic sequence as a list of [ratio, idx] (elements from notes_sorted).
  #            This should always be in ascending order.
  #       NOTE The algo simply uses the last 2 elements to calculate the next term in the seq to look for.
  #
  # remaining_search_terms: Sorted sublist of a copy of rats_sorted_indexed that excludes
  #                         ratios that are already included in the arith_seq
  search = []

  #
  # populate search list with all combinations of the first two notes.
  #

  oct_idx_pairs = (0...notes_octs[0].size).to_a.repeated_permutation(2).to_a
  (0...rats.size).to_a.combination(2) { |r_idx1, r_idx2|
    rem_terms = notes_sorted.filter { |_, i, _| i != r_idx1 and i != r_idx2 }
    oct_idx_pairs.each{ |o1, o2|
      incl_idxs = [r_idx1, r_idx2]
      first_two = [notes_octs[r_idx1][o1], notes_octs[r_idx2][o2]].sort
      within_max_arith_diff = first_two[1][0] / first_two[0][0] < max_arith_diff
      lower_passes_fix_check = !fix.include?(first_two[0][1]) || first_two[0][2] == 0
      upper_passes_fix_check = !fix.include?(first_two[1][1]) || first_two[1][2] == 0
      if within_max_arith_diff and lower_passes_fix_check and upper_passes_fix_check
        search.push [incl_idxs, first_two, rem_terms]
      end
    }
  }

  # Each entry in here is an isoharmonic subsequence that fulfills all the criteria.
  # Successive entries are longer or equal in length to the previous entry.
  #
  # @type [Array<Array<Rational>>]
  output = []

  search.each { |incl_idxs, arith_seq, rem_terms|
    last_rat, last_idx, _ = *arith_seq[-1]
    penult_rat, penult_idx, _ = *arith_seq[-2]
    rat_collection = [penult_rat, last_rat]
    looking_for = rat_collection[-1] * 2 - rat_collection[-2]
    used_idx = [penult_idx, last_idx].to_set

    # rem_terms should be in increasing order
    rem_terms.each { |rat, idx, oct|
      next if used_idx.include?(idx)
      break if rat > looking_for # since it's sorted

      # Reminder: don't need to check for max arith diff again as it is constant

      if rat == looking_for && (!fix.include?(idx) || oct == 0)
        rat_collection.push rat
        used_idx.add idx
        looking_for = rat_collection[-1] * 2 - rat_collection[-2]
      end
    }

    if output.size == 0 or rat_collection.size >= output[-1].size
      output.push rat_collection
    end
  }

  return output
end
