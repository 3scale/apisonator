require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Extensions
  class HashTest < Test::Unit::TestCase
    test '#symbolize_keys' do
      input    = {'foo' => 'bla bla', 'bar' => 'la la la'}
      expected = {:foo  => 'bla bla', :bar  => 'la la la'}

      assert_equal expected, input.symbolize_keys
    end

    test '#slice' do
      input = {'foo' => 1, 'bar' => 2, 'baz' => 3}

      assert_equal({'foo' => 1},             input.slice('foo'))
      assert_equal({'foo' => 1, 'baz' => 3}, input.slice('foo', 'baz'))

      assert_equal({},                       input.slice('qux'))
    end
  end
end
