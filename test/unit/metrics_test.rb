require File.dirname(__FILE__) + '/../test_helper'

class MetricsTest < Test::Unit::TestCase
  include TestHelpers::EventMachine

  def setup
    @service_id = 1001
    @storage = ThreeScale::Backend.storage
    @storage.flushdb
  end

  def test_process_usage_maps_metric_names_to_ids
    metrics = Metrics.new(2001 => {:name => 'hits'}, 2002 => {:name => 'transfer'})

    input  = {'hits' => 1, 'transfer' => 1024}

    actual_output   = metrics.process_usage(input)
    expected_output = {'2001' => 1, '2002' => 1024}

    assert_equal expected_output, actual_output
  end

  def test_process_usage_handles_metric_names_with_messed_up_case
    metrics = Metrics.new(2001 => {:name => 'hits'})
    assert_equal({'2001' => 1}, metrics.process_usage('HiTs' => 1))
  end

  def test_process_usage_handles_metric_names_with_leading_or_trailing_whitespace_junk
    metrics = Metrics.new(2001 => {:name => 'hits'})
    assert_equal({'2001' => 1}, metrics.process_usage("  hits\n\t " => 1))
  end

  def test_process_usage_handles_empty_input
    metrics = Metrics.new(2001 => {:name => 'hits'})
    assert_equal({}, metrics.process_usage({}))
  end

  def test_process_usage_raises_an_exception_on_invalid_metric_name
    metrics = Metrics.new(2001 => {:name => 'hits'})

    assert_raise MetricNotFound do
      metrics.process_usage('ninjastars' => 1000)
    end
  end

  def test_process_usage_raises_an_exception_on_blank_usage_value
    metrics = Metrics.new(2001 => {:name => 'hits'})

    assert_raise UsageValueInvalid do
      metrics.process_usage('hits' => '')
    end
  end

  def test_process_usage_raises_an_exception_on_non_numeric_usage_value
    metrics = Metrics.new(2001 => {:name => 'hits'})

    assert_raise UsageValueInvalid do
      metrics.process_usage('hits' => 'a lot!')
    end
  end

  def test_process_usage_handles_hierarchical_metrics
    metrics = Metrics.new(2001 => {:name => 'hits',
                                   :children => {2002 => {:name => 'search_queries'}}})

    assert_equal({'2001' => 1, '2002' => 1}, metrics.process_usage('search_queries' => 1))
  end

  def test_load
    @storage.set("metric/id/service_id:#{@service_id}/name:hits", 2001)
    @storage.set("metric/id/service_id:#{@service_id}/name:search_queries", 2002)
    @storage.set("metric/id/service_id:#{@service_id}/name:transfer", 2003)

    @storage.set("metric/parent_id/service_id:#{@service_id}/id:2002", 2001)

    metrics = Metrics.load(@service_id)
    usage   = {'search_queries' => 18, 'transfer' => 2048}

    assert_equal({'2001' => 18, '2002' => 18, '2003' => 2048}, metrics.process_usage(usage))
  end

  def test_save
    Metrics.save(:service_id => @service_id,
                 2001 => {:name => 'hits', :children => {2002 => {:name => 'search_queries'}}},
                 2003 => {:name => 'transfer'})

    assert_equal '2001', @storage.get("metric/id/service_id:#{@service_id}/name:hits")
    assert_equal '2002', @storage.get("metric/id/service_id:#{@service_id}/name:search_queries")
    assert_equal '2003', @storage.get("metric/id/service_id:#{@service_id}/name:transfer")

    assert_equal '2001', @storage.get("metric/parent_id/service_id:#{@service_id}/id:2002")
    assert_nil           @storage.get("metric/parent_id/service_id:#{@service_id}/id:2001")
    assert_nil           @storage.get("metric/parent_id/service_id:#{@service_id}/id:2003")
  end
end
