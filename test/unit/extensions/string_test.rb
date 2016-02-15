require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Extensions
  class StringTest < Test::Unit::TestCase
    def test_blank?
      assert  ''.blank?
      assert  '  '.blank?
      assert !'foo'.blank?
    end
  end
end
