require File.dirname(__FILE__) + '/../test_helper'

class AggregationTest < Test::Unit::TestCase
  include TestHelpers::EventMachine

  def setup
    @storage = ThreeScale::Backend.storage
    @storage.flushdb
  end

  def test_aggregate_increments_all_stats_values_and_updates_all_source_sets
    Aggregation.aggregate(:service    => 1001,
                          :cinstance  => 2001,
                          :created_at => Time.local(2010, 5, 7, 13, 23, 33),
                          :usage      => {'3001' => 1})

    assert_equal '1', @storage.get("stats/{service:1001}/metric:3001/eternity")
    assert_equal '1', @storage.get("stats/{service:1001}/metric:3001/month:20100501")
    assert_equal '1', @storage.get("stats/{service:1001}/metric:3001/week:20100503")
    assert_equal '1', @storage.get("stats/{service:1001}/metric:3001/day:20100507")
    assert_equal '1', @storage.get("stats/{service:1001}/metric:3001/21600:2010050712")
    assert_equal '1', @storage.get("stats/{service:1001}/metric:3001/hour:2010050713")
    assert_equal '1', @storage.get("stats/{service:1001}/metric:3001/120:201005071322")

    assert_equal '1', @storage.get("stats/{service:1001}/cinstance:2001/metric:3001/eternity")
    assert_equal '1', @storage.get("stats/{service:1001}/cinstance:2001/metric:3001/year:20100101")
    assert_equal '1', @storage.get("stats/{service:1001}/cinstance:2001/metric:3001/month:20100501")
    assert_equal '1', @storage.get("stats/{service:1001}/cinstance:2001/metric:3001/week:20100503")
    assert_equal '1', @storage.get("stats/{service:1001}/cinstance:2001/metric:3001/day:20100507")
    assert_equal '1', @storage.get("stats/{service:1001}/cinstance:2001/metric:3001/21600:2010050712")
    assert_equal '1', @storage.get("stats/{service:1001}/cinstance:2001/metric:3001/hour:2010050713")
    assert_equal '1', @storage.get("stats/{service:1001}/cinstance:2001/metric:3001/minute:201005071323")

    assert_equal ['2001'], @storage.smembers("stats/{service:1001}/cinstance_set")
  end
end
