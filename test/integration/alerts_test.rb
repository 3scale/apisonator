require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class AlertsTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::StorageKeys
  include Backend::Alerts

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!
    Memoizer.reset!

    setup_provider_fixtures

    @application_id1 = next_id
    Application.save(:service_id => @service_id,
                     :id         => @application_id1,
                     :plan_id    => @plan_id,
                     :state      => :active)

    @application_id2 = next_id
    Application.save(:service_id => @service_id,
                     :id         => @application_id2,
                     :plan_id    => @plan_id,
                     :state      => :active)

    @foos_id = next_id
    Metric.save(:service_id => @service_id, :id => @foos_id, :name => 'foos')

    UsageLimit.save(:service_id => @service_id,
                    :plan_id    => @plan_id,
                    :metric_id  => @foos_id,
                    :month        => 100)

    Alerts::ALERT_BINS.each do |val|
      AlertLimit.save(@service_id, val)
    end
  end

  test 'only one event for each application is stored per alert_ttl changing the alert limits' do
    timestamp = Time.utc(2010, 5, 14, 12, 00, 00)

    assert_equal 0, EventStorage.list().size

    Timecop.freeze(timestamp) do
      Transactor.report(@provider_key,
                        @service_id,
                        0 => {'app_id' => @application_id1, 'usage' => {'foos' => 90}})
      Backend::Transactor.process_full_batch
      Resque.run!
    end

    Timecop.freeze(timestamp + Alerts::ALERT_TTL*0.5) do
      Transactor.report(@provider_key,
                        @service_id,
                        0 => {'app_id' => @application_id1, 'usage' => {'foos' => 1}})
      Backend::Transactor.process_full_batch
      Resque.run!
    end

    ## now we are 3.0 days later, this should report a violation again
    tmp_res = @storage.del("alerts/service_id:#{@service_id}/app_id:#{@application_id1}/#{90}/already_notified")
    assert_equal tmp_res, 1

    Timecop.freeze(timestamp + Alerts::ALERT_TTL*3.0) do
      Transactor.report(@provider_key,
                        @service_id,
                        0 => {'app_id' => @application_id1, 'usage' => {'foos' => 1}})
      Backend::Transactor.process_full_batch
      Resque.run!

      AlertLimit.delete(@service_id, 100)

      ## this one should over 100 and below 120 should not happen since
      Transactor.report(@provider_key,
                        @service_id,
                        0 => {'app_id' => @application_id1, 'usage' => {'foos' => 10}})
      Backend::Transactor.process_full_batch
      Resque.run!

      AlertLimit.save(@service_id, 100)

      Transactor.report(@provider_key,
                        @service_id,
                        0 => {'app_id' => @application_id1, 'usage' => {'foos' => 20}})
      Backend::Transactor.process_full_batch
      Resque.run!
    end

    v = []
    EventStorage.list.each do |event|
      v << event if event[:type] == 'alert'
    end

    assert_equal 3, v.size

    ## again redis-2.6 yeilds a different order
    cont = 0

    v.each do |item|
      assert_equal true, [1,2,3].include?(item[:object][:id])

      if item[:object][:id] == 1
        assert_equal 90, item[:object][:utilization]
        cont = cont + 1
      end

      if item[:object][:id] == 2
        assert_equal 90, item[:object][:utilization]
        cont = cont + 1
      end

      if item[:object][:id] == 3
        assert_equal 120, item[:object][:utilization]
        cont = cont + 1
      end
    end

    assert_equal 3, cont
  end

  test 'only one event for each application is stored per alert_ttl' do
    timestamp = Time.utc(2010, 5, 14, 12, 00, 00)

    assert_equal 0, EventStorage.list.size

    Timecop.freeze(timestamp) do
      Transactor.report(@provider_key,
                        @service_id,
                        0 => {'app_id' => @application_id1, 'usage' => {'foos' => 90}})
      Backend::Transactor.process_full_batch
      Resque.run!
    end

    Timecop.freeze(timestamp + Alerts::ALERT_TTL*0.5) do
      Transactor.report(@provider_key,
                        @service_id,
                        0 => {'app_id' => @application_id1, 'usage' => {'foos' => 1}})
      Backend::Transactor.process_full_batch
      Resque.run!
    end

    ## now we are 3.0 days later, this should report a violation again
    tmp_res = @storage.del("alerts/service_id:#{@service_id}/app_id:#{@application_id1}/#{90}/already_notified")

    assert_equal tmp_res, 1

    Timecop.freeze(timestamp + Alerts::ALERT_TTL*3.0) do
      Transactor.report(@provider_key,
                        @service_id,
                        0 => {'app_id' => @application_id1, 'usage' => {'foos' => 1}})
      Backend::Transactor.process_full_batch
      Resque.run!

      Transactor.report(@provider_key,
                        @service_id,
                        0 => {'app_id' => @application_id1, 'usage' => {'foos' => 10}})
      Backend::Transactor.process_full_batch
      Resque.run!
    end

    v = []
    EventStorage.list().each do |event|
      if event[:type] == 'alert'
        v << event[:object][:utilization]
      end
    end

    assert_equal 3, v.size
    assert v.include? 100
    assert v.include? 90
  end
end
