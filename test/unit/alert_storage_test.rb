require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class AlertStorageTest < Test::Unit::TestCase
  include TestHelpers::Sequences

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb
    
    @service_id     = next_id
    @application_id = next_id
    @metric_id      = next_id
  end

  test 'list operation on alerts deletes the list' do
    timestamp = Time.now.utc
    AlertStorage.store(:id => next_id, :service_id => @service_id, :application_id => @application_id, :utilization => 90, :max_utilization => 90.0, :limit => "metric X: 90 of 100", :timestamp => timestamp)
    AlertStorage.store(:id => next_id, :service_id => @service_id, :application_id => @application_id, :utilization => 100, :max_utilization => 100.0, :limit => "metric X: 100 of 100", :timestamp => timestamp)
    assert_equal 2, AlertStorage.list(@service_id).size
    assert_equal 0, AlertStorage.list(@service_id).size
  end

  test 'test addition and retrieval' do
    application_id_one = @application_id
    application_id_two = next_id

    service_id_one = @service_id
    service_id_two = next_id

    timestamp = Time.now.utc

    AlertStorage.store(:id => next_id, :service_id => service_id_one, :application_id => application_id_one, :utilization => 90, :max_utilization => 90.0, :limit => "metric X: 90 of 100", :timestamp => timestamp)
    AlertStorage.store(:id => next_id, :service_id => service_id_one, :application_id => application_id_one, :utilization => 100, :max_utilization => 100.0, :limit => "metric X: 100 of 100", :timestamp => timestamp)
    alert_id = next_id
    AlertStorage.store(:id => alert_id, :service_id => service_id_one, :application_id => application_id_two, :utilization => 90, :max_utilization => 90.0,:limit => "metric X: 90 of 100", :timestamp => timestamp)

    AlertStorage.store(:id => next_id, :service_id => service_id_two, :application_id => application_id_one, :utilization => 90, :max_utilization => 90.0, :limit => "metric X: 90 of 100", :timestamp => timestamp)
    AlertStorage.store(:id => next_id, :service_id => service_id_two, :application_id => application_id_one, :utilization => 100, :max_utilization => 100.0, :limit => "metric X: 100 of 100", :timestamp => timestamp)
    AlertStorage.store(:id => next_id, :service_id => service_id_two, :application_id => application_id_two, :utilization => "90", :max_utilization => 90.0, :limit => "metric X: 100 of 100", :timestamp => timestamp)

    v1 = AlertStorage.list(service_id_one).map{|e| e.to_json}
    v2 = AlertStorage.list(service_id_two).map{|e| e.to_json}


    assert_equal 3, v1.size
    assert_equal 3, v2.size


    expected = {:id           => alert_id,
                :service_id    => service_id_one,
                :application_id => application_id_two,
                :utilization    => 90,
                :max_utilization    => 90.0,
                :limit          => "metric X: 90 of 100",
                :timestamp      => timestamp}

    assert v1.include? expected.to_json

    expected = {:id           => (alert_id.to_i-1).to_s,
                :service_id    => service_id_one,
                :application_id => application_id_one,
                :utilization    => 100,
                :max_utilization    => 100.0,
                :limit          => "metric X: 100 of 100",
                :timestamp      => timestamp}

    assert v1.include? expected.to_json
  end
end
