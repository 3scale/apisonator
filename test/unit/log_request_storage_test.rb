require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class LogRequestStorageTest < Test::Unit::TestCase
  include TestHelpers::Sequences

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    @service_id     = next_id
    @application_id = next_id
    @metric_id      = next_id
  end

  test '#store_all stores transactions that are not complete on usage' do
    service_id_one = @service_id
    service_id_two = next_id
    application_id_one = @application_id
    application_id_two = next_id

    log1 = {:service_id     => service_id_one,
            :application_id => application_id_one,
            :timestamp      => Time.utc(2010, 9, 10, 17, 4),
            :usage          => "",
            :log            => {'request' => 'req', 'code' => 200}}

    log2 = {:service_id     => service_id_one,
            :application_id => application_id_two,
            :usage          => nil,
            :timestamp      => Time.utc(2010, 9, 10, 17, 10),
            :log            => {'request' => 'req2'}}

    LogRequestStorage.store_all([log1, log2])
    list = LogRequestStorage.list_by_service(service_id_one)

    assert_equal 2, list.size
    assert_equal 2, LogRequestStorage.count_by_service(service_id_one)

    ## the order is reversed, newer first
    assert_equal log1, list[1]
    assert_equal log2, list[0]

    list = LogRequestStorage.list_by_service(service_id_two)
    assert_equal 0, list.size
    assert_equal 0, LogRequestStorage.count_by_service(service_id_two)

    list = LogRequestStorage.list_by_application(service_id_one,application_id_one)
    assert_equal 1, list.size
    assert_equal 1, LogRequestStorage.count_by_application(service_id_one,application_id_one)
    assert_equal log1, list[0]

    list = LogRequestStorage.list_by_application(service_id_one,application_id_two)
    assert_equal 1, list.size
    assert_equal 1, LogRequestStorage.count_by_application(service_id_one,application_id_two)
    assert_equal log2, list[0]

    LogRequestStorage.delete_by_application(service_id_one,application_id_two)
    list = LogRequestStorage.list_by_application(service_id_one,application_id_two)
    assert_equal 0, list.size

    list = LogRequestStorage.list_by_service(service_id_one)
    assert_equal 2, list.size

    LogRequestStorage.delete_by_service(service_id_two)
    list = LogRequestStorage.list_by_service(service_id_one)
    assert_equal 2, list.size

    LogRequestStorage.delete_by_service(service_id_one)
    list = LogRequestStorage.list_by_service(service_id_one)
    assert_equal 0, list.size
  end
end

