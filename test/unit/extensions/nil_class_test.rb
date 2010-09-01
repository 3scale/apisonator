require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Extensions
  class NilClassTest < Test::Unit::TestCase
    def test_blank?
      assert nil.blank?
    end
  end
end
