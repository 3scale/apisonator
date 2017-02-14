require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Extensions
  class HashTest < Test::Unit::TestCase
    def test_symbolize_names
      input    = {'foo' => 'bla bla', 'bar' => 'la la la'}
      expected = {:foo  => 'bla bla', :bar  => 'la la la'}

      assert_equal expected, input.symbolize_names
    end
  end
end
