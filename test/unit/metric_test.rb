require File.dirname(__FILE__) + '/../test_helper'

class MetricTest < Test::Unit::TestCase
  include TestHelpers::EventMachine

  def setup
    @service_id = 1001
    @storage = ThreeScale::Backend.storage
    @storage.flushdb
  end

  def test_save
    metric = Metric.new(:service_id => @service_id, :id => 2001, :name => 'hits')
    metric.save

    assert_equal '2001', @storage.get("metric/service_id:#{@service_id}/name:hits/id")
    assert_nil           @storage.get("metric/service_id:#{@service_id}/id:2001/parent_id")
  end

  def test_save_with_children
    metric = Metric.new(:service_id => @service_id, :id => 2001, :name => 'hits')
    metric.children << Metric.new(:id => 2002, :name => 'search_queries')
    metric.save

    assert_equal '2001', @storage.get("metric/service_id:#{@service_id}/name:hits/id")
    assert_equal '2002', @storage.get("metric/service_id:#{@service_id}/name:search_queries/id")
    assert_equal '2001', @storage.get("metric/service_id:#{@service_id}/id:2002/parent_id")
  end
end
