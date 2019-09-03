require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class MetricTest < Test::Unit::TestCase
  include TestHelpers::Sequences
  include TestHelpers::MetricsHierarchy

  attr_reader :storage

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb
    Memoizer.reset!
  end

  def test_save
    metric = Metric.new(:service_id => 1001, :id => 2001, :name => 'hits')
    metric.save

    assert_equal '2001',   storage.get("metric/service_id:1001/name:hits/id")
    assert_equal 'hits',   storage.get("metric/service_id:1001/id:2001/name")
    assert_equal ['2001'], storage.smembers("metrics/service_id:1001/ids")

    assert_nil storage.get("metric/service_id:1001/id:2001/parent_id")
  end

  def test_save_with_children
    metric = Metric.new(:service_id => 1001, :id => 2001, :name => 'hits')
    metric.children << Metric.new(:id => 2002, :name => 'search_queries')
    metric.save

    assert_equal '2001', storage.get("metric/service_id:1001/name:hits/id")
    assert_equal 'hits', storage.get("metric/service_id:1001/id:2001/name")
    assert_nil           storage.get("metric/service_id:1001/id:2001/parent_id")

    assert_equal '2002',           storage.get("metric/service_id:1001/name:search_queries/id")
    assert_equal 'search_queries', storage.get("metric/service_id:1001/id:2002/name")
    assert_equal '2001',           storage.get("metric/service_id:1001/id:2002/parent_id")

    assert_equal ['2001', '2002'], storage.smembers("metrics/service_id:1001/ids").sort
  end

  def test_load_parent_id
    parent_id = 2011
    metric = Metric.new(:service_id => 1001, :id => parent_id, :name => 'hits')
    child = Metric.new(:id => 2012, :name => 'search_queries')
    metric.children << child
    metric.save

    assert_equal parent_id, Metric.load_parent_id(metric.service_id, child.id).to_i
    assert_nil Metric.load_parent_id(metric.service_id, metric.id)
  end

  def test_hierarchy_with_children
    service_id = 1001
    parent1 = { service_id: service_id, id: 2020, name: 'parent1' }
    parent2 = { service_id: service_id, id: 2030, name: 'parent2' }

    metric1 = Metric.new(parent1)
    metric1.children << Metric.new(:id => parent1[:id] + 1, :name => 'p1_children1')
    metric1.children << Metric.new(:id => parent1[:id] + 2, :name => 'p1_children2')
    metric1.save

    metric2 = Metric.new(parent2)
    metric2.children << Metric.new(:id => parent2[:id] + 1, :name => 'p2_children1')
    metric2.save

    mh_ids = Metric.hierarchy(service_id, false)
    assert_equal metric1.children.map(&:id).sort, mh_ids[parent1[:id].to_s].map(&:to_i).sort
    assert_equal metric2.children.map(&:id).sort, mh_ids[parent2[:id].to_s].map(&:to_i).sort

    # assert that children don't have any children themselves
    assert([metric1.children, metric2.children].all? do |mc|
      mc.all? do |m|
        mh_ids[m.id.to_s].nil?
      end
    end)

    mh_names = Metric.hierarchy(service_id)
    assert_equal metric1.children.map(&:name).sort, mh_names[parent1[:name]].sort
    assert_equal metric2.children.map(&:name).sort, mh_names[parent2[:name]].sort

    # assert that children don't have any children themselves
    assert([metric1.children, metric2.children].all? do |mc|
      mc.all? do |m|
        mh_names[m.name].nil?
      end
    end)

    mc = Metric.children(1001, parent1[:id])
    assert_equal metric1.children.map(&:id).sort, mc.map(&:to_i).sort
  end

  def test_hierarchy_without_children
    service_id = 1001
    parent_id = 2040
    parent = { service_id: service_id, id: parent_id, name: 'parent_wo_children' }
    metric = Metric.new(parent)
    metric.save

    assert_empty metric.children
    assert_nil Metric.children(1001, parent_id)

    mh = Metric.hierarchy(service_id, false)

    assert_nil mh[parent[:id].to_s]
    assert mh.values.all? { |children| !children.include?(parent_id.to_s) }
  end

  def test_rename
    # renames should behave like saves but reverse mappings should be deleted
    # and names updated.
    metric = Metric.new(:service_id => 1001, :id => 2001, :name => 'hits')
    metric.save

    assert_equal '2001',   storage.get("metric/service_id:1001/name:hits/id")
    assert_equal 'hits',   storage.get("metric/service_id:1001/id:2001/name")
    assert_equal ['2001'], storage.smembers("metrics/service_id:1001/ids")
    assert_nil             storage.get("metric/service_id:1001/id:2001/parent_id")

    metric2 = Metric.new(:service_id => 1001, :id => 2001, :name => 'renamed_hits')
    metric2.save

    assert_equal '2001',         storage.get("metric/service_id:1001/name:renamed_hits/id")
    assert_equal 'renamed_hits', storage.get("metric/service_id:1001/id:2001/name")
    assert_equal ['2001'],       storage.smembers("metrics/service_id:1001/ids")
    assert_nil                   storage.get("metric/service_id:1001/id:2001/parent_id")

    assert_nil                   storage.get("metric/service_id:1001/name:hits/id")
  end

  def test_load
    Metric.save(:service_id => 1001, :id => 2001, :name => 'foos')

    metric = Metric.load(1001, 2001)
    assert_not_nil metric
    assert_equal '2001', metric.id
    assert_equal '1001', metric.service_id
    assert_equal 'foos', metric.name
  end

  def test_load_all_ids
    Metric.save(:service_id => 1001, :id => 2001, :name => 'foos')
    Metric.save(:service_id => 1001, :id => 2002, :name => 'bars')
    Metric.save(:service_id => 1002, :id => 2003, :name => 'bazs')

    assert_equal ['2001', '2002'], Metric.load_all_ids(1001)

    Metric.save(:service_id => 1001, :id => 2003, :name => 'barf')
    assert_equal ['2001', '2002', '2003'], Metric.load_all_ids(1001)
  end

  def test_load_all_ids_returns_empty_array_if_no_ids_found
    assert_equal [], Metric.load_all_ids(1001)
  end

  def test_load_name
    Metric.save(:service_id => 1001, :id => 2001, :name => 'bananas')
    assert_equal 'bananas', Metric.load_name(1001, 2001)
    Metric.save(:service_id => 1001, :id => 2001, :name => 'monkeys')
    assert_equal 'monkeys', Metric.load_name(1001, 2001)
  end

  def test_all_names
    Metric.save(:service_id => 1001, :id => 2001, :name => 'bananas')
    Metric.save(:service_id => 1001, :id => 2002, :name => 'bananas2')
    name_hash = Metric.load_all_names(1001, [2001,2002])
    assert_equal 'bananas', name_hash[2001]
    assert_equal 'bananas2', name_hash[2002]
    Metric.save(:service_id => 1001, :id => 2001, :name => 'monkeys')
    name_hash = Metric.load_all_names(1001, [2001, 2002])
    assert_equal 'monkeys', name_hash[2001]

    assert_empty Metric.load_all_names(1001, [])
    assert_empty Metric.load_all_names(100, nil)
  end

  def test_load_id
    Metric.save(:service_id => 1001, :id => 2002, :name => 'monkeys')
    assert_equal '2002', Metric.load_id(1001, 'monkeys')
  end

  def test_delete
    Metric.save(:service_id => 1001, :id => 2003, :name => 'donkeys')
    Metric.delete(1001, 2003)

    assert_nil Metric.load(1001, 2003)
    assert_nil Metric.load_id(1001, 'donkeys')
    assert !Metric.load_all_ids(1001).include?('2003')
    Metric.save(:service_id => 1001, :id => 2003, :name => 'donkeys')
    assert_not_nil Metric.load(1001, 2003)
    assert Metric.load_all_ids(1001).include?('2003')
  end

  def test_parents
    service_id = next_id
    Service.save!(provider_key: 'a_provider_key', id: service_id)

    metric = Metric.new(service_id: service_id, id: next_id, name: 'parent1')
    metric.children << Metric.new(id: next_id, name: 'child1')
    metric.save

    metric = Metric.new(service_id: service_id, id: next_id, name: 'parent2')
    metric.children << Metric.new(id: next_id, name: 'child2')
    metric.save

    assert_equal %w(parent1 parent2),
                 Metric.parents(service_id, %w(child1 child2))
  end

  def test_parents_with_non_existing_service
    assert_empty Metric.parents('non_existing', %w(metric1, metric2))
  end

  def test_parents_with_service_wo_metrics
    service_id = next_id
    Service.save!(provider_key: 'a_provider_key', id: service_id)
    assert_empty Metric.parents(service_id, [])
  end

  def test_parents_with_non_existing_metrics
    service_id = next_id
    Service.save!(provider_key: 'a_provider_key', id: service_id)
    assert_empty Metric.parents(service_id, %w(non_existing_1 non_existing_2))
  end

  def test_parents_with_metrics_wo_parents
    service_id = next_id
    Service.save!(provider_key: 'a_provider_key', id: service_id)

    metrics = %w(metric1 metric2)
    metrics.each do |metric|
      Metric.save(service_id: service_id, id: next_id, name: metric)
    end

    assert_empty Metric.parents(service_id, metrics)
  end

  def test_parents_does_not_include_duplicates
    service_id = next_id
    Service.save!(provider_key: 'a_provider_key', id: service_id)

    parent = Metric.new(service_id: service_id, id: next_id, name: 'parent')
    child1 = Metric.new(service_id: service_id, id: next_id, name: 'child1')
    child2 = Metric.new(service_id: service_id, id: next_id, name: 'child2')
    parent.children = [child1, child2]
    parent.save

    assert_equal(['parent'], Metric.parents(service_id, %w(child1 child2)))
  end

  def test_descendants
    service_id = next_id
    Service.save!(provider_key: 'a_provider_key', id: service_id)
    levels = rand(3..10)
    metrics = gen_hierarchy_one_metric_per_level(service_id, levels)

    assert_true metrics.each_with_index.all? do |metric, idx|
      descendants = Metric.descendants(service_id, metric.name)

      # The descendants could be in any order
      descendants.sort == metrics[idx+1..-1].map(&:name).sort
    end
  end

  def test_ascendants
    service_id = next_id
    Service.save!(provider_key: 'a_provider_key', id: service_id)
    levels = rand(3..10)
    metrics = gen_hierarchy_one_metric_per_level(service_id, levels)

    assert_true metrics.each_with_index.all? do |metric, idx|
      ascendants = Metric.ascendants(service_id, metric.name)

      ascendants.sort == metrics.take(idx).(&:name).sort
    end
  end
end
