require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class AggregatorTest < Test::Unit::TestCase
  include TestHelpers::StorageKeys
  include TestHelpers::Fixtures

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb
    Memoizer.reset!
    seed_data
    setup_provider_fixtures
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

  test '.process can generate usage alerts' do
    app_id = next_id
    metric_id = next_id
    limit_max_val = 10
    alert_level = 50

    Application.save(service_id: @service_id, id: app_id, state: :active, plan_id: @plan_id)
    Metric.save(service_id: @service_id, id: metric_id, name: 'some_metric')
    AlertLimit.save(@service_id, alert_level)
    UsageLimit.save(
      service_id: @service_id, plan_id: @plan_id, metric_id: metric_id, hour: limit_max_val
    )

    transaction =  Transaction.new(
      service_id: @service_id,
      application_id: app_id,
      timestamp: Time.now,
      usage: { metric_id => limit_max_val/2 } # The alert level defined is 50% so this should alert
    )

    Stats::Aggregator.process([transaction])

    # There could be other events apart from alerts (first traffic, first daily
    # traffic), those have :type != 'alert'.
    # Only one alert should have been raised (50%).
    alerts = EventStorage.list.select { |event| event[:type] == 'alert' }
    assert_equal 1, alerts.size

    alert = alerts.first
    assert_equal @service_id, alert[:object][:service_id]
    assert_equal app_id, alert[:object][:application_id]
    assert_equal 50, alert[:object][:utilization]
  end

  test '.process can generate usage alerts when not checking all the usage limits' do
    # The update_alerts method has two paths. In the first one, it checks all
    # the usage limits. In the second one, thanks to the Alerts::UsagesChecked
    # class it only needs to check the limits of the metrics included in the
    # report job. This test checks that second path.

    app_id = next_id
    metric_1_id = next_id
    metric_2_id = next_id
    limit_max_val = 10
    alert_level = 50

    Application.save(service_id: @service_id, id: app_id, state: :active, plan_id: @plan_id)
    Metric.save(service_id: @service_id, id: metric_1_id, name: 'some_metric')
    Metric.save(service_id: @service_id, id: metric_2_id, name: 'another_metric')
    AlertLimit.save(@service_id, alert_level)

    [metric_1_id, metric_2_id].each do |metric_id|
      UsageLimit.save(
        service_id: @service_id, plan_id: @plan_id, metric_id: metric_id, hour: limit_max_val
      )
    end

    # Transaction that does not raise alert (level is defined at 50%)
    transaction =  Transaction.new(
      service_id: @service_id,
      application_id: app_id,
      timestamp: Time.now,
      usage: { metric_1_id => 1 }
    )
    Stats::Aggregator.process([transaction])
    assert_empty EventStorage.list.select { |event| event[:type] == 'alert' }

    # The previous transaction checked all the usage limits. The next one will
    # only check the ones coming in the request.

    transaction =  Transaction.new(
      service_id: @service_id,
      application_id: app_id,
      timestamp: Time.now,
      usage: { metric_2_id => limit_max_val/2 } # The alert level is 50% so this should alert
    )
    Stats::Aggregator.process([transaction])

    alerts = EventStorage.list.select { |event| event[:type] == 'alert' }
    assert_equal 1, alerts.size

    alert = alerts.first[:object]
    assert_equal @service_id, alert[:service_id]
    assert_equal app_id, alert[:application_id]
    assert_equal 50, alert[:utilization]
  end

  test '.process takes into account all the transactions when generating alerts' do
    app_id = next_id
    n_metrics = 3
    metric_ids = n_metrics.times.map { next_id }
    limit_max_val = 10
    alert_level = 50

    Application.save(service_id: @service_id, id: app_id, state: :active, plan_id: @plan_id)

    metric_ids.each do |metric_id|
      # Reuse metric ID as name to avoid conflicts
      Metric.save(service_id: @service_id, id: metric_id, name: metric_id)

      UsageLimit.save(
        service_id: @service_id, plan_id: @plan_id, metric_id: metric_id, hour: limit_max_val
      )
    end

    AlertLimit.save(@service_id, alert_level)

    # This array contains 2 transactions. Notice that the second one reports 2
    # metrics. This allows us to verify that the aggregator checks all the
    # metrics in all the transactions when deciding if an alert should be
    # triggered.
    transactions = [
      Transaction.new(
        service_id: @service_id,
        application_id: app_id,
        timestamp: Time.now,
        usage: { metric_ids[0] => 1 } # Does not trigger an alert
      ),
      Transaction.new(
        service_id: @service_id,
        application_id: app_id,
        timestamp: Time.now,
        # the usage reported for metrics_ids[2] triggers an alert (level defined
        # 50%).
        usage: { metric_ids[1] => 1, metric_ids[2] => limit_max_val/2 }
      )
    ]

    Stats::Aggregator.process(transactions)

    alerts = EventStorage.list.select { |event| event[:type] == 'alert' }
    assert_equal 1, alerts.size

    alert = alerts.first[:object]
    assert_equal @service_id, alert[:service_id]
    assert_equal app_id, alert[:application_id]
    assert_equal 50, alert[:utilization]
  end
end
