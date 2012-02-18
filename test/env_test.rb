require File.join(File.dirname(__FILE__), '..', 'lib', 'homeostasis', 'env')
require 'minitest/autorun'

class EnvTest < MiniTest::Unit::TestCase
  def test_environment
    assert(Homeostasis::ENV.development?)
    refute(Homeostasis::ENV.production?)
  end

  def test_method_missing
    assert_raises(NoMethodError) { Homeostasis::ENV.nomethod }
  end
end
