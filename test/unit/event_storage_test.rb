require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class EventStorageTest < Test::Unit::TestCase
  include TestHelpers::Sequences
  include StorageHelpers

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    @service_id     = next_id
    @application_id = next_id
    @metric_id      = next_id
  end

  test 'test addition and retrieval' do

    timestamp = Time.now.utc

    alerts = []
    10.times.each do |i|
      alerts << {:id => next_id, :service_id => i, :application_id => "app1", :utilization => 90,
        :max_utilization => 90.0, :limit => "metric X: 90 of 100", :timestamp => timestamp}
    end

    assert_equal 0, EventStorage.size()
    assert_equal 0, EventStorage.list().size

    EventStorage.store(:alert, alerts[0])
    EventStorage.store(:alert, alerts[1])

    list = EventStorage.list()
    saved_id = list.last[:id]


    EventStorage.store(:alert, alerts[2])

    assert_equal 3, EventStorage.size()
    assert_equal 3, EventStorage.list().size

    list = EventStorage.list()

    list.size.times.each do |i|
      assert_equal encode(alerts[i]), encode(list[i][:object])
      assert_equal "alert", list[i][:type]
    end
  end

  test 'ping behavior' do

    Airbrake.stubs(:notify).returns(true)

    saved_ttl = EventStorage::PING_TTL

    EventStorage.redef_without_warning("PING_TTL", 1)

    # empty queue
    assert_equal false, EventStorage.ping_if_not_empty

    # add an event, false becase not events_hook defined
    EventStorage.store(:alert, {})
    assert_equal false, EventStorage.ping_if_not_empty

    # add an event, false becase not events_hook empty
    configuration.events_hook = ""
    assert_equal false, EventStorage.ping_if_not_empty

    ## add events_hook, nil because it fails to connect
    configuration.events_hook = "foobar"

    assert_equal nil, EventStorage.ping_if_not_empty

    sleep(EventStorage::PING_TTL+1)

    ## add stubbing
    RestClient.stubs(:post).returns(true)
    assert_equal true, EventStorage.ping_if_not_empty

    ## false only report once per TTL
    10.times.each do
      assert_equal false, EventStorage.ping_if_not_empty
    end

    sleep(EventStorage::PING_TTL+1)

    ## true because TTL has elapsed
    assert_equal true, EventStorage.ping_if_not_empty

    ## false only report once per TTL
    10.times.each do
      assert_equal false, EventStorage.ping_if_not_empty
    end

    sleep(EventStorage::PING_TTL+1)

    EventStorage.delete_range(999999)

    ## false because no events
    assert_equal false, EventStorage.ping_if_not_empty

    configuration.events_hook = nil
    ThreeScale::Backend.configuration.events_hook = nil

    EventStorage.redef_without_warning("PING_TTL", saved_ttl)
    RestClient.unstub(:post)
    Airbrake.unstub(:notify)

  end

end
