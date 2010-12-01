require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class UsageLimitTest < Test::Unit::TestCase
  def setup
    @storage = Storage.instance(true)
    @storage.flushdb
  end

  test 'validate returns false if the limit is exceeded' do
    usage_limit = UsageLimit.new(:metric_id => 4001, :period => :day, :value => 200)
    assert !usage_limit.validate(:day => {4001 => 213})
  end

  test 'validate returns true if the limit is not exceeded' do
    usage_limit = UsageLimit.new(:metric_id => 4001, :period => :day, :value => 200)
    assert usage_limit.validate(:day => {4001 => 199})
  end
end
