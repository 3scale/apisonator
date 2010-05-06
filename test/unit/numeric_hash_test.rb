require File.dirname(__FILE__) + '/../test_helper'

class NumericHashTest < Test::Unit::TestCase
  def test_update_with_numeric_hash
    usage_one = NumericHash.new(42 => 1, 43 => 2)
    usage_two = NumericHash.new(42 => 3, 44 => 4)

    result = usage_one.update(usage_two)

    assert_instance_of NumericHash, result
    assert_same result, usage_one
    assert_equal NumericHash.new(42 => 3, 43 => 2, 44 => 4), usage_one
  end

  def test_update_with_hash
    usage = NumericHash.new(42 => 1)
    result = usage.update(43 => 2)

    assert_instance_of NumericHash, result
    assert_same result, usage
    assert_equal NumericHash.new(42 => 1, 43 => 2), usage
  end

  def test_addition
    usage_one = NumericHash.new(42 => 2, 43 => 3)
    usage_two = NumericHash.new(42 => 1)

    assert_equal NumericHash.new(42 => 3, 43 => 3), usage_one + usage_two
    assert_equal NumericHash.new(42 => 3, 43 => 3), usage_two + usage_one
  end

  def test_subtraction
    usage_one = NumericHash.new(42 => 2, 43 => 3)
    usage_two = NumericHash.new(42 => 1)

    assert_equal NumericHash.new(42 => 1, 43 => 3), usage_one - usage_two
    assert_equal NumericHash.new(42 => -1, 43 => -3), usage_two - usage_one
  end

  def test_map
    usage = NumericHash.new(42 => 1, 43 => 2)
    mapped = usage.map { |key, value| [key, value] }

    assert mapped.include?([42, 1]), 'does not contain the element'
    assert mapped.include?([43, 2]), 'does not contain the element'
  end

  def test_element_access
    usage = NumericHash.new(42 => 1, 43 => 2)

    assert_equal 1, usage[42]
    assert_equal 2, usage[43]
    assert_nil usage[44]
  end

  def test_blank?
    assert  NumericHash.new.blank?
    assert !NumericHash.new(42 => 1).blank?
  end

  def test_reset!
    usage = NumericHash.new(42 => 1)
    usage.reset!

    assert usage.blank?
  end

  def test_nonzero?
    assert !NumericHash.new.nonzero?
    assert !NumericHash.new(41 => 0, 42 => 0).nonzero?
    assert  NumericHash.new(42 => 1).nonzero?
  end
end
