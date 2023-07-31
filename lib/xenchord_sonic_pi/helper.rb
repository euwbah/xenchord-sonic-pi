# HELPER METHODS
# Run order: 4/4

require 'json'

def tihai_search(notes_min, notes_max, rest_min, rest_max, target_matra)

end

# send osc
def o(*args)
  osc_send($IP_ADDR, 9000, *args)
end

# Play a monzo or monzo-constructor parameter
# Accepts var arguments of monzos, followed by play kwargs
def p(*args, **kwargs)
  return if args.size == 0
  chd_monzos = args.map { |a|
    Monzo.new(a)
  }
  chd = chd_monzos.map{ |a|
    hz = a.ratio * ROOT
    o('/note', a.primes.to_json, a.ratio * ROOT)
    hz_to_midi hz
  }.to_a
  play_chord chd, **kwargs
end

# euclidean cycle with additive numerical result
# size: size of array
# args: var args in groups of 3, each group representing one euclidean rhythm:
#   (number accents, rotation, number to add)
# returns a ring of numbers.
def euc(size, *args)
  assert args.size % 3 == 0, "euc must have additional arguments in multiples of 3"
  l = args.each_slice(3).map {|acc, rot, num|
    [spread(acc, size, rotate: rot), num]
  }.reduce([0]*size) {|acc, (e_bools, num) |
    puts e_bools, num
    (0...size).map{
      acc[_1] + (e_bools[_1] ? num : 0)
    }.to_a
  }
  ring(*l)
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
def farey(n)
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

# Input a list of Rationals that represent pitch classes modulo
# the octave. Input should be normalized to appear within 1/1 to 2/1.
#
# The octave equivalence is applied based on ISO_OCT_EQV_BOUNDS.
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
def isoharm_search_full(rats, max_arith_diff=2r)
  bel, abv = *ISO_OCT_EQV_BOUNDS

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
def isoharm_search(rats, max_arith_diff=2r)
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
# This algo returns all isoharmonic subsets of length 3 and above.
#
# Only returns the longest isoharmonic series that fulfils the notes to fix.
def isoharm_search_2(rats, max_arith_diff=2r, fix=[])
  bel, abv = *ISO_OCT_EQV_BOUNDS

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
      lower_passes_fix_check = not fix.include?(first_two[0][0]) or first_two[0][2] == 0
      upper_passes_fix_check = not fix.include?(first_two[1][0]) or first_two[1][2] == 0
      if within_max_arith_diff and lower_passes_fix_check and upper_passes_fix_check
        search.push [incl_idxs, first_two, rem_terms]
      end
    }
  }

  search.each { |incl_idxs, arith_seq, rem_terms|
    last_rat, last_idx, last_oct = *arith_seq[-1]
    penult_rat, penult_idx, penult_oct = *arith_seq[-2]
    looking_for = last_rat * 2 - penult_rat
    sequence_collection = []
    # rem_terms is in sorted order
    rem_terms.each { |rat, idx, oct|
    }
  }
end
