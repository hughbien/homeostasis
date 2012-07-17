require 'rubygems'
require 'stasis'
require 'minitest/autorun'

Stasis.new(File.expand_path(File.join(File.dirname(__FILE__), 'fixture')))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'homeostasis', 'path'))

class PathTest < MiniTest::Unit::TestCase
  def setup
    @plugin = Homeostasis::Path.new(nil)
  end

  def test_path
    assert_equal('/blog.html', @plugin.path('/blog'))
    assert_equal('blog.html', @plugin.path('blog'))
  end
end
