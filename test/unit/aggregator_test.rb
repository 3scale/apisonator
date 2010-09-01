require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class AggregatorTest < Test::Unit::TestCase
  include TestHelpers::StorageKeys

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb
  end

  def test_aggregate_increments_all_stats_counters
    Aggregator.aggregate([{:service_id     => 1001,
                           :application_id => 2001,
                           :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                           :usage          => {'3001' => 1}}])

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

  def test_aggregate_updates_application_set
    Aggregator.aggregate([{:service_id     => 1001,
                           :application_id => 2001,
                           :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                           :usage          => {'3001' => 1}}])
    
    assert_equal ['2001'], @storage.smembers("stats/{service:1001}/cinstances")
  end
    
  def test_aggregate_does_not_update_service_set
    assert_no_change :of => lambda { @storage.smembers('stats/services') } do
      Aggregator.aggregate([{:service_id     => '1001',
                             :application_id => '2001',
                             :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                             :usage          => {'3001' => 1}}])
    end
  end
    
  def test_aggregate_sets_expiration_time_for_volatile_keys
    Aggregator.aggregate([{:service_id     => '1001',
                           :application_id => '2001',
                           :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                           :usage          => {'3001' => 1}}])

    key = application_key('1001', '2001', '3001', :minute, 201005071323)
    ttl = @storage.ttl(key)

    assert_not_equal -1, ttl
    assert ttl >  0
    assert ttl <= 60
  end
end
