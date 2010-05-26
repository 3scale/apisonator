require File.dirname(__FILE__) + '/../test_helper'

class UsageLimitTest < Test::Unit::TestCase
  include TestHelpers::EventMachine

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb
  end

  def test_validate_raises_an_exception_if_the_limit_is_exceeded
    usage_limit = UsageLimit.new(:metric_id => 4001, :period => :day, :value => 200)

    assert_raise LimitsExceeded do
      usage_limit.validate(:day => {4001 => 213})
    end
  end
  
  def test_validate_returns_true_if_the_limit_is_not_exceeded
    usage_limit = UsageLimit.new(:metric_id => 4001, :period => :day, :value => 200)
    assert usage_limit.validate(:day => {4001 => 199})
  end
end
