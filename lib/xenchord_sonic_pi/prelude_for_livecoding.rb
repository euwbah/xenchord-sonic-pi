# Run this file in Sonic Pi before beginning live coding session
# This will run all the necessary files.

require "prime"
require "json"

$LIB_ROOT = "C:/Users/dacoo/Documents/SonicPiProj/xenchord-sonic-pi/lib/xenchord_sonic_pi"
$IP_ADDR = "10.0.0.20"

$GLO = self

$PRIME_LIMIT = 1331
$PRIME_IDX_TABLE = Hash[Prime.each($PRIME_LIMIT).each_with_index.map { |p, idx| [p, idx + 1] }]
$PRIMES = $PRIME_IDX_TABLE.keys

$ISO_OCT_EQV_BOUNDS = [-2, 3].freeze # bounds of oct eqv for isoharm search.

# base frequency of 1/1 in Hz.
$F0_HZ = 220r

run_file "#{$LIB_ROOT}/polyfills.rb"
run_file "#{$LIB_ROOT}/calculations.rb" # exposes $CALC
run_file "#{$LIB_ROOT}/dataclasses.rb"
run_file "#{$LIB_ROOT}/helper.rb"
