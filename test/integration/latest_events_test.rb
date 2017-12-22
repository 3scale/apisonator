require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require '3scale/backend/alert_limit'

class LatestEventsTest < Test::Unit::TestCase
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

    @application_id3 = next_id
    Application.save(:service_id => @service_id,
                     :id         => @application_id3,
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

  test 'test correct results for first_traffic events with authrep' do
      authrep(app_id: @application_id1, usage: { 'foos' => 1 })

      ## processes all the pending NotifyJobs. This creates a NotifyJob with the
      ## aggregate and another Resque.run! is needed
      Backend::Transactor.process_full_batch
      Resque.run!

      events = EventStorage.list
      assert_equal 4, events.size

      app_events = events[0..1]
      master_app_events = events[2..3]

      assert_equal app_events.first[:type], 'first_traffic'
      assert_equal app_events.last[:type], 'first_daily_traffic'
      assert_equal master_app_events.first[:type], 'first_traffic'
      assert_equal master_app_events.last[:type], 'first_daily_traffic'
      assert_equal true, app_events.first[:object][:service_id] == @service_id
      assert_equal true, master_app_events.first[:object][:service_id] == @master_service_id

      assert_equal 4, EventStorage.delete_range(99999999)

      assert_equal 0, EventStorage.size

      authrep(app_id: @application_id2, usage: { 'foos' => 1 })
      authrep(app_id: @application_id3, usage: {'foos' => 1 })

      events = EventStorage.list
      assert_equal 4, events.size

      app_2_events = events[0..1]
      app_3_events = events[2..3]

      assert_equal app_2_events.first[:type], 'first_traffic'
      assert_equal app_2_events.last[:type], 'first_daily_traffic'
      assert_equal true, app_2_events.first[:object][:service_id] == @service_id
      assert_equal true, app_2_events.last[:object][:service_id] == @service_id
      assert_equal true, app_2_events.first[:object][:application_id] == @application_id2
      assert_equal true, app_2_events.last[:object][:application_id] == @application_id2

      assert_equal app_3_events.first[:type], 'first_traffic'
      assert_equal app_3_events.last[:type], 'first_daily_traffic'
      assert_equal true, app_3_events.first[:object][:service_id] == @service_id
      assert_equal true, app_3_events.last[:object][:service_id] == @service_id
      assert_equal true, app_3_events.first[:object][:application_id] == @application_id3
      assert_equal true, app_3_events.last[:object][:application_id] == @application_id3

      assert_equal 4, EventStorage.delete_range(10_000)

      assert_equal 0, EventStorage.size

      authrep(app_id: @application_id2, usage: { 'foos' => 1 })
      authrep(app_id: @application_id3, usage: { 'foos' => 1})

      ## now it's empty because @application_id1, and @application_id2 first_traffic event already raised
      assert_equal 0, EventStorage.size

      assert_equal 0, EventStorage.delete_range(10_000)
  end

  test 'test correct results for events with authrep' do
    authrep(app_id: @application_id1, usage: { 'foos' => 81 })
    authrep(app_id: @application_id1, usage: { 'foos' => 10 })
    authrep(app_id: @application_id2, usage: { 'foos' => 81 })
    authrep(app_id: @application_id3, usage: { 'foos' => 81 })

    Backend::Transactor.process_full_batch
    Resque.run!

    assert_equal 12, EventStorage.size

    filter_events_by_type("alert")

    events = EventStorage.list
    assert_equal 4, events.size

    events.each do |item|
      assert_equal 'alert', item[:type]
    end

    saved_id = -1
    events.each do |item|
      if item[:type] == 'alert' && item[:object][:application_id].to_i == @application_id3.to_i
        saved_id = item[:id]
        assert_equal @service_id.to_i, item[:object][:service_id].to_i
        assert_equal @application_id3.to_i, item[:object][:application_id].to_i
        assert_equal '80'.to_i, item[:object][:utilization].to_i
        assert_equal 'foos per month: 81/100', item[:object][:limit]
        assert_not_nil item[:object][:timestamp]
        assert_not_nil item[:object][:id]
      end
    end
    assert_not_equal(-1, saved_id)

    EventStorage.delete(saved_id)

    events = EventStorage.list
    assert_equal 3, events.size
    events.each { |item| assert_not_equal saved_id.to_i, item[:id].to_i }
  end

  test 'test alerts with authrep' do
    authrep(app_id: @application_id1, usage: { 'foos' => 99 })

    filter_events_by_type('alert')

    assert_equal 1, EventStorage.size

    filter_events_by_type('alert')

    assert_equal 1, EventStorage.size

    authrep(app_id: @application_id2, usage: { 'foos' => 99 })

    assert_equal 200, last_response.status

    filter_events_by_type('alert')

    assert_equal 2, EventStorage.size

    authrep(app_id: @application_id1, usage: { 'foos' => 1 })

    assert_equal 200, last_response.status

    filter_events_by_type('alert')

    assert_equal 3, EventStorage.size

    filter_events_by_type('alert')

    assert_equal 3, EventStorage.size
  end

  test 'test correct results for alerts with reports' do
    ## alerts over 100% cannot happen on authrep
    report({ 0 => { app_id: @application_id1, usage: { 'foos' => 115 }}})
    report({ 0 => { app_id: @application_id1, usage: { 'foos' => 10 }}})
    report({ 0 => { app_id: @application_id2, usage: { 'foos' => 115 }}})
    report({ 0 => { app_id: @application_id3, usage: { 'foos' => 115 }}})

    Backend::Transactor.process_full_batch
    Resque.run!

    ## 4 alerts, 3 first_traffic for the apps, 3 first_daily_traffic for the
    ## apps, 1 first_traffic for master app, 1 first_daily_traffic for master app
    assert_equal 4+1+1+3+3, EventStorage.size

    filter_events_by_type('alert')

    events = EventStorage.list
    assert_equal 4, events.size

    saved_id = -1
    events.each do |item|
      if item[:type] == 'alert' && item[:object][:application_id].to_i == @application_id3.to_i
        saved_id = item[:id]
        assert_equal @service_id.to_i, item[:object][:service_id].to_i
        assert_equal @application_id3.to_i, item[:object][:application_id].to_i
        assert_equal '100'.to_i, item[:object][:utilization].to_i
        assert_equal 'foos per month: 115/100', item[:object][:limit]
        assert_not_nil item[:object][:timestamp]
        assert_not_nil item[:object][:id]
      end
    end
    assert_not_equal(-1, saved_id)
  end

  test 'events_hook is triggered on report' do
    EventStorage.stubs(:request_to_events_hook).at_least_once.returns(true)

    configuration.events_hook = 'http://foobar.foobar'

    post '/transactions.xml',
      provider_key: @provider_key,
      transactions: { 0 => { app_id: @application_id1, usage: { 'foos' => 115 } } }

    Resque.run!

    EventStorage.unstub(:request_to_events_hook)
    configuration.events_hook = ''
  end

  test 'events_hook is triggered on authrep' do
    EventStorage.stubs(:request_to_events_hook).at_least_once.returns(true)

    configuration.events_hook = 'http://foobar.foobar'

    authrep(app_id: @application_id1, usage: { 'foos' => 99 })

    EventStorage.unstub(:request_to_events_hook)
    configuration.events_hook = ''
  end

  private

  def filter_events_by_type(type)
    EventStorage.list.each do |item|
      EventStorage.delete(item[:id]) if item[:type] != type
    end
  end

  def authrep(params)
    get '/transactions/authrep.xml', params.merge(provider_key: @provider_key)
    assert_equal 200, last_response.status
    Resque.run!
  end

  def report(transactions)
    post '/transactions.xml',
         provider_key: @provider_key, transactions: transactions
    assert_equal 202, last_response.status
    Resque.run!
  end
end
