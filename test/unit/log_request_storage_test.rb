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

  test '#store_all stores transactions' do
    service_id_one = @service_id
    service_id_two = next_id
    application_id_one = @application_id
    application_id_two = next_id
    metric_id_one = @metric_id
    metric_id_two = next_id

    log1 = {:service_id     => service_id_one,
            :application_id => application_id_one,
            :usage          => {metric_id_one => 1},
            :timestamp      => Time.utc(2010, 9, 10, 17, 4),
            :log            => {'request' => 'req', 'response' => 'resp', 'code' => 200}}

    log2 = {:service_id     => service_id_one,
            :application_id => application_id_two,
            :usage          => {metric_id_two => 2},
            :timestamp      => Time.utc(2010, 9, 10, 17, 10),
            :log            => {'request' => 'req2', 'response' => 'resp2', 'code' => 404}}
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

  test '#store_all stores transactions that are not complete' do
    service_id_one = @service_id
    service_id_two = next_id

    application_id_one = @application_id
    application_id_two = next_id

    log1 = {:service_id     => service_id_one,
            :application_id => application_id_one,
            :timestamp      => Time.utc(2010, 9, 10, 17, 4),
            :usage          => "",
            :log            => {'request' => 'req', 'response' => 'resp', 'code' => 200}}

    log2 = {:service_id     => service_id_one,
            :application_id => application_id_two,
            :usage          => nil,
            :timestamp      => Time.utc(2010, 9, 10, 17, 10),
            :log            => {'request' => 'req2', 'response' => 'resp2', 'code' => 404}}
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

  test 'respects the limits of the lists' do
    log1 = {:service_id     => @service_id,
            :application_id => @application_id,
            :usage          => {"metric_id_one" => 1},
            :timestamp      => Time.utc(2010, 9, 10, 17, 4),
            :log            => {'request' => 'req', 'response' => 'resp', 'code' => 200}}

    (LogRequestStorage::LIMIT_PER_SERVICE+LogRequestStorage::LIMIT_PER_APP).times do
      LogRequestStorage.store(log1)
    end

    assert_equal LogRequestStorage::LIMIT_PER_SERVICE, @storage.llen("logs/service_id:#{@service_id}")
    assert_equal LogRequestStorage::LIMIT_PER_APP, @storage.llen("logs/service_id:#{@service_id}/app_id:#{@application_id}")
  end
end

