# frozen_string_literal: true
require "test_helper"
require "xenchord_sonic_pi/helper"
require "xenchord_sonic_pi/calculations"

class Xenchord_Sonic_PiTest < Minitest::Test
  def test_calculations

    c = CalcSingleton.new

    puts c.lcm_heuristic
    return true
  end
end
