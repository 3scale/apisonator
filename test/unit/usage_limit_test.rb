require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class UsageLimitTest < Test::Unit::TestCase
  def setup
    @storage = Storage.instance(true)
    @storage.flushdb
  end

  def test_validate_returns_false_if_the_limit_is_exceeded
    usage_limit = UsageLimit.new(:metric_id => 4001, :period => :day, :value => 200)
    assert !usage_limit.validate(:day => {4001 => 213})
  end
  
  def test_validate_returns_true_if_the_limit_is_not_exceeded
    usage_limit = UsageLimit.new(:metric_id => 4001, :period => :day, :value => 200)
    assert usage_limit.validate(:day => {4001 => 199})
  end
end
