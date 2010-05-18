require File.dirname(__FILE__) + '/../test_helper'

class MetricTest < Test::Unit::TestCase
  include TestHelpers::EventMachine

  def setup
    @storage = Storage.instance
    @storage.flushdb
  end

  def test_save
    metric = Metric.new(:service_id => 1001, :id => 2001, :name => 'hits')
    metric.save

    assert_equal '2001', @storage.get("metric/service_id:1001/name:hits/id")
    assert_equal 'hits', @storage.get("metric/service_id:1001/id:2001/name")
    assert_nil           @storage.get("metric/service_id:1001/id:2001/parent_id")

    assert_equal ['2001'], @storage.smembers("metrics/service_id:1001/ids")
  end

  def test_save_with_children
    metric = Metric.new(:service_id => 1001, :id => 2001, :name => 'hits')
    metric.children << Metric.new(:id => 2002, :name => 'search_queries')
    metric.save

    assert_equal '2001', @storage.get("metric/service_id:1001/name:hits/id")
    assert_equal '2002', @storage.get("metric/service_id:1001/name:search_queries/id")
    assert_equal '2001', @storage.get("metric/service_id:1001/id:2002/parent_id")
    
    assert_equal ['2001', '2002'], @storage.smembers("metrics/service_id:1001/ids").sort
  end

  def test_load_all_ids
    Metric.save(:service_id => 1001, :id => 2001, :name => 'foos')
    Metric.save(:service_id => 1001, :id => 2002, :name => 'bars')
    Metric.save(:service_id => 1002, :id => 2003, :name => 'bazs')

    assert_equal ['2001', '2002'], Metric.load_all_ids(1001).sort
  end

  def test_load_name
    Metric.save(:service_id => 1001, :id => 2001, :name => 'bananas')

    assert_equal 'bananas', Metric.load_name(1001, 2001)
  end
end
