require 'rubygems'
require 'stasis'
require 'minitest/autorun'

STASIS = Stasis.new(File.expand_path(File.join(File.dirname(__FILE__), 'fixture')))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'homeostasis', 'front'))

class PathTest < MiniTest::Unit::TestCase
  def setup
    @plugin = Homeostasis::Front.new(STASIS)
  end

  def test_front
  end
end
