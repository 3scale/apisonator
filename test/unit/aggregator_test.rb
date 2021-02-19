require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class AggregatorTest < Test::Unit::TestCase
  include TestHelpers::StorageKeys
  include TestHelpers::Fixtures

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb
    Memoizer.reset!
    seed_data
  end

  test 'process increments_all_stats_counters' do
    Stats::Aggregator.process([default_transaction])

    assert_equal '1', @storage.get(service_key(1001, 3001, :eternity))
    assert_equal '1', @storage.get(service_key(1001, 3001, :month,  '20100501'))
    assert_equal '1', @storage.get(service_key(1001, 3001, :week,   '20100503'))
    assert_equal '1', @storage.get(service_key(1001, 3001, :day,    '20100507'))
    assert_equal '1', @storage.get(service_key(1001, 3001, :hour,   '2010050713'))

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :eternity))
    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :year,   '20100101'))
    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :month,  '20100501'))
    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :week,   '20100503'))
    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :day,    '20100507'))
    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :minute, '201005071323'))
  end

  test 'process updates application set' do
    Stats::Aggregator.process([default_transaction])

    assert_equal ['2001'], @storage.smembers("stats/{service:1001}/cinstances")
  end

  test 'process does not update service set' do
    assert_no_change of: lambda { @storage.smembers('stats/services') } do
      Stats::Aggregator.process([default_transaction])
    end
  end

  test 'process sets expiration time for volatile keys' do
    Stats::Aggregator.process([default_transaction])

    key = application_key('1001', '2001', '3001', :minute, 201005071323)
    ttl = @storage.ttl(key)

    assert_not_equal(-1, ttl)
    assert ttl >  0
    assert ttl <= 180
  end

  test 'aggregate takes into account setting the counter value' do
    v = Array.new(10, default_transaction)
    v << transaction_with_set_value
    v << default_transaction

    Stats::Aggregator.process(v)

    assert_equal '666', @storage.get(application_key(1001, 2001, 3001, :hour, '2010050713'))
  end

  # Ref: https://github.com/3scale/apisonator/issues/264
  test 'process does not raise when the application no longer exists' do
    Application.delete(default_transaction.service_id, default_transaction.application_id)

    assert_nothing_raised do
      Stats::Aggregator.process([default_transaction])
    end
  end
end
