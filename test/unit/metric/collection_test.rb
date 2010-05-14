require File.dirname(__FILE__) + '/../../test_helper'

module Metric
  class CollectionTest < Test::Unit::TestCase
    include TestHelpers::EventMachine

    def setup
      ThreeScale::Backend.storage.flushdb
    end

    def test_process_usage_maps_metric_names_to_ids
      Metric.save(:service_id => 1001, :id => 2001, :name => 'hits')
      Metric.save(:service_id => 1001, :id => 2002, :name => 'transfer')
      metrics = Metric::Collection.new(1001)

      input  = {'hits' => 1, 'transfer' => 1024}

      actual_output   = metrics.process_usage(input)
      expected_output = {'2001' => 1, '2002' => 1024}

      assert_equal expected_output, actual_output
    end

    def test_process_usage_handles_metric_names_with_messed_up_case
      Metric.save(:service_id => 1001, :id => 2001, :name => 'hits')
      metrics = Metric::Collection.new(1001)
      
      assert_equal({'2001' => 1}, metrics.process_usage('HiTs' => 1))
    end

    def test_process_usage_handles_metric_names_with_leading_or_trailing_whitespace_junk
      Metric.save(:service_id => 1001, :id => 2001, :name => 'hits')
      metrics = Metric::Collection.new(1001)

      assert_equal({'2001' => 1}, metrics.process_usage("  hits\n\t " => 1))
    end

    def test_process_usage_handles_empty_input
      Metric.save(:service_id => 1001, :id => 2001, :name => 'hits')
      metrics = Metric::Collection.new(1001)

      assert_equal({}, metrics.process_usage({}))
    end

    def test_process_usage_raises_an_exception_on_invalid_metric_name
      Metric.save(:service_id => 1001, :id => 2001, :name => 'hits')
      metrics = Metric::Collection.new(1001)

      assert_raise MetricNotFound do
        metrics.process_usage('ninjastars' => 1000)
      end
    end

    def test_process_usage_raises_an_exception_on_blank_usage_value
      Metric.save(:service_id => 1001, :id => 2001, :name => 'hits')
      metrics = Metric::Collection.new(1001)

      assert_raise UsageValueInvalid do
        metrics.process_usage('hits' => '')
      end
    end

    def test_process_usage_raises_an_exception_on_non_numeric_usage_value
      Metric.save(:service_id => 1001, :id => 2001, :name => 'hits')
      metrics = Metric::Collection.new(1001)

      assert_raise UsageValueInvalid do
        metrics.process_usage('hits' => 'a lot!')
      end
    end

    def test_process_usage_handles_hierarchical_metrics
      metric = Metric.new(:service_id => 1001, :id => 2001, :name => 'hits')
      metric.children << Metric.new(:id => 2002, :name => 'search_queries')
      metric.save
      
      metrics = Metric::Collection.new(1001)

      assert_equal({'2001' => 1, '2002' => 1}, metrics.process_usage('search_queries' => 1))
    end
  end
end
