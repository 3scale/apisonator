require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Metric
  class CollectionTest < Test::Unit::TestCase
    include TestHelpers::Sequences
    include TestHelpers::MetricsHierarchy

    def setup
      Storage.instance(true).flushdb
      Memoizer.reset!
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

      assert_raise MetricInvalid do
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

    def test_process_usage_handles_hierarchical_metrics_with_set_values
      metric = Metric.new(:service_id => 1001, :id => 2001, :name => 'hits')
      metric.children << Metric.new(:id => 2002, :name => 'hits_child_1')
      metric.children << Metric.new(:id => 2003, :name => 'hits_child_2')
      metric.save

      metrics = Metric::Collection.new(1001)

      assert_equal({'2001' => 5, '2002' => 2, '2003' => 3}, metrics.process_usage('hits_child_1' => 2, 'hits_child_2' => 3))
      assert_equal({'2001' => 11, '2002' => 2, '2003' => 3}, metrics.process_usage('hits' => 6, 'hits_child_1' => 2, 'hits_child_2' => 3))

      assert_equal({'2001' => '#6'}, metrics.process_usage('hits' => '#6'))
      assert_equal({'2001' => '#6', '2002' => '#6'}, metrics.process_usage('hits_child_1' => '#6'))
      assert_equal({'2001' => '#11', '2002' => '#6', '2003' => '#11'}, metrics.process_usage('hits_child_1' => '#6', 'hits_child_2' => '#11'))
    end

    def test_process_usage_handles_hierarchies_with_more_than_2_levels
      # This test generates a hierarchy with more than 2 levels and one metric
      # per level.
      # Also, it creates a usage where the metrics at the last and last + 1
      # levels of the hierarchy have 1 hit. Then, it checks that those hits are
      # correctly propagated, that is, all the metrics in the hierarchy should
      # have 2 hits, except the one at the bottom which should have only 1.

      service_id = next_id
      levels = rand(3..10)
      metrics = gen_hierarchy_one_metric_per_level(service_id, levels)

      metrics_collection = Metric::Collection.new(service_id)
      processed = metrics_collection.process_usage(
        metrics.last.name => 1, metrics[-2].name => 1
      )

      assert_equal(1, processed[metrics.last.id])
      assert_true metrics[0..-2].all? do |metric|
        processed[metric.id] == 2
      end
    end

    def test_process_usage_ignores_hierarchy_when_asked_to_via_flat_usage
      metric = Metric.new(:service_id => 1001, :id => 2001, :name => 'hits')
      metric.children << Metric.new(:id => 2002, :name => 'hits_child_1')
      metric.children << Metric.new(:id => 2003, :name => 'hits_child_2')
      metric.save

      metrics = Metric::Collection.new(1001)

      assert_equal({'2002' => 2, '2003' => 3},
        metrics.process_usage({'hits_child_1' => 2, 'hits_child_2' => 3}, true))
      assert_equal({'2001' => 6, '2002' => 2, '2003' => 3},
        metrics.process_usage({'hits' => 6, 'hits_child_1' => 2, 'hits_child_2' => 3}, true))

      assert_equal({'2001' => '#6'},
                   metrics.process_usage({'hits' => '#6'}, true))
      assert_equal({'2002' => '#6'},
                   metrics.process_usage({'hits_child_1' => '#6'}, true))
      assert_equal({'2002' => '#6', '2003' => '#11'},
                   metrics.process_usage({'hits_child_1' => '#6',
                                          'hits_child_2' => '#11'}, true))
    end
  end
end
