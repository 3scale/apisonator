require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class UsageLimitTest < Test::Unit::TestCase
  def storage
    @storage ||= Storage.instance(true)
  end

  def setup
    storage.flushdb
  end

  test 'validate returns false if the limit is exceeded' do
    usage_limit = UsageLimit.new(:metric_id => 4001, :period => :day, :value => 200)
    assert !usage_limit.validate(:day => {4001 => 213})
  end

  test 'validate returns true if the limit is not exceeded' do
    usage_limit = UsageLimit.new(:metric_id => 4001, :period => :day, :value => 200)
    assert usage_limit.validate(:day => {4001 => 199})
  end

  def test_save
    UsageLimit.save(:service_id => '2001',
                    :plan_id    => '3001',
                    :metric_id  => '4001',
                    :month      => 1000000,
                    :week       => 300000,
                    :day        => 45000,
                    :hour       => 2000,
                    :minute     => 10)

    assert_equal '1000000',
                 storage.get('usage_limit/service_id:2001/plan_id:3001/metric_id:4001/month')

    assert_equal '300000',
                 storage.get('usage_limit/service_id:2001/plan_id:3001/metric_id:4001/week')

    assert_equal '45000',
                 storage.get('usage_limit/service_id:2001/plan_id:3001/metric_id:4001/day')

    assert_equal '2000',
                 storage.get('usage_limit/service_id:2001/plan_id:3001/metric_id:4001/hour')

    assert_equal '10',
                 storage.get('usage_limit/service_id:2001/plan_id:3001/metric_id:4001/minute')
  end

  def test_load_all
    Metric.save(:service_id => 2001, :id => 4001, :name => 'hits')
    Metric.save(:service_id => 2001, :id => 4002, :name => 'transfer')

    UsageLimit.save(service_id: 2001, plan_id: 3001, metric_id: 4001, month: 1000)
    UsageLimit.save(service_id: 2001, plan_id: 3001, metric_id: 4001, week: 500)
    UsageLimit.save(service_id: 2001, plan_id: 3001, metric_id: 4002, month: 2100)

    usage_limits = UsageLimit.load_all(2001, 3001)
    assert_equal 3, usage_limits.count
    # test memoization is cleared when deleting and saving
    someul = usage_limits.sample
    UsageLimit.delete(someul.service_id, someul.plan_id, someul.metric_id, someul.period)
    usage_limits = UsageLimit.load_all(2001, 3001)
    assert_equal 2, usage_limits.count
    # take care not to overwrite metric/period combination by using year
    UsageLimit.save(service_id: 2001, plan_id: 3001, metric_id: 4002, year: 10000)
    usage_limits = UsageLimit.load_all(2001, 3001)
    assert_equal 3, usage_limits.count
  end

  def test_load_for_affecting_metrics
    service_id = 2001
    plan_id = 3001
    metric_1_id = 4001
    metric_2_id = 4002

    Metric.save(service_id: service_id, id: metric_1_id, name: 'some_metric')
    Metric.save(service_id: service_id, id: metric_2_id, name: 'another_metric')

    # 2 limits for the first metric and 1 for the second
    UsageLimit.save(service_id: service_id, plan_id: plan_id, metric_id: metric_1_id, month: 10)
    UsageLimit.save(service_id: service_id, plan_id: plan_id, metric_id: metric_1_id, week: 5)
    UsageLimit.save(service_id: service_id, plan_id: plan_id, metric_id: metric_2_id, month: 20)

    # returns only the 2 limits of the first metric
    usage_limits = UsageLimit.load_for_affecting_metrics(service_id, plan_id, [metric_1_id])
    assert_equal 2, usage_limits.count
    assert usage_limits.all? { |limit| limit.metric_id == metric_1_id }

    # returns only the limit of the second metric
    usage_limits = UsageLimit.load_for_affecting_metrics(service_id, plan_id, [metric_2_id])
    assert_equal 1, usage_limits.count
    assert_equal metric_2_id, usage_limits.first.metric_id
  end

  def test_load_all_returns_empty_array_if_there_are_no_metrics
    UsageLimit.load_all(2001, 3001).each do |ul|
      UsageLimit.delete(ul.service_id, ul.plan_id, ul.metric_id, ul.period)
    end

    usage_limits = UsageLimit.load_all(2001, 3001)
    assert usage_limits.empty?, 'Expected usage_limits to be empty'
  end

  def test_usage_limit_periods_do_not_include_second
    assert_nil(UsageLimit::PERIODS.find { |period| period == :second })
  end

  def test_save_refuses_second_as_period
    UsageLimit.save(service_id: 2001,
                    plan_id: 3001,
                    metric_id: 4001,
                    second: 100)

    assert_nil UsageLimit.load_value(2001, 3001, 4001, :second)
  end

  def test_load_value
    UsageLimit.save(:service_id => 2001,
                    :plan_id    => 3001,
                    :metric_id  => 4001,
                    :hour       => 500)

    assert_equal 500, UsageLimit.load_value(2001, 3001, 4001, :hour)
  end

  def test_load_value_return_nil_if_the_usage_limit_does_not_exist
    assert_nil UsageLimit.load_value(2001, 3001, 4001, :hour)
  end

  def test_delete
    Metric.save(:service_id => 2001, :id => 4001, :name => 'hits')
    UsageLimit.save(:service_id => 2001,
                    :plan_id    => 3001,
                    :metric_id  => 4001,
                    :minute     => 10)

    UsageLimit.delete(2001, 3001, 4001, :minute)

    assert_nil UsageLimit.load_value(2001, 3001, 4001, :minute)

    usage_limits = UsageLimit.load_all(2001, 3001)
    assert usage_limits.none? { |limit| limit.metric_id == '4001' && limit.period == :minute }
  end

  def test_metric_name
    Metric.save(:service_id => 2001, :id => 4001, :name => 'hits')
    usage_limit = UsageLimit.new(:service_id => '2001',
                                 :plan_id    => '3001',
                                 :metric_id  => '4001')

    metric_name = usage_limit.metric_name
    assert_equal 'hits', metric_name
  end

  def test_value_is_numeric
    Metric.save(:service_id => 2001, :id => 4001, :name => 'hits')
    UsageLimit.save(:service_id => '2001',
                    :plan_id    => '3001',
                    :metric_id  => '4001',
                    :month      => 1000000)
    usage_limit = UsageLimit.load_all(2001, 3001).first

    assert_equal 1000000, usage_limit.value
  end

  def test_save_with_eternity
    UsageLimit.save(:service_id => '2001',
                    :plan_id    => '3001',
                    :metric_id  => '4001',
                    :month      => 1000000,
                    :eternity   => 300000)

    assert_equal '1000000',
                 storage.get('usage_limit/service_id:2001/plan_id:3001/metric_id:4001/month')

    assert_equal '300000',
                 storage.get('usage_limit/service_id:2001/plan_id:3001/metric_id:4001/eternity')

  end

  def test_delete_with_eternity
    Metric.save(:service_id => 2001, :id => 4001, :name => 'hits')
    UsageLimit.save(:service_id => 2001,
                    :plan_id    => 3001,
                    :metric_id  => 4001,
                    :minute     => 10,
                    :eternity   => 1000)

    UsageLimit.delete(2001, 3001, 4001, :eternity)

    assert_nil UsageLimit.load_value(2001, 3001, 4001, :eternity)

    usage_limits = UsageLimit.load_all(2001, 3001)
    assert usage_limits.none? { |limit| limit.metric_id == '4001' && limit.period == :eternity }

    assert_equal usage_limits.first.period, :minute
  end
end
