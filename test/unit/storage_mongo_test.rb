require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class StorageMongoTest < Test::Unit::TestCase
  def setup
    @storage = StorageMongo.instance(true)
    @storage.clear_collections
  end

  test 'failures on connections' do
    ## pretend that mongodb is not running (note the intentionally wrong port)

    bkp_configuration  = configuration.clone

    configuration.mongo.servers = ["localhost:9090"]
    configuration.mongo.db = StorageMongo::DEFAULT_DATABASE

    ## this is fine because it's the good instance from the setup
    storage = StorageMongo.instance
    assert_not_nil storage
    assert_equal [storage.client.host,storage.client.port].join(":"), StorageMongo::DEFAULT_SERVER

    ## but now it shouldn't because we are reloading.

    assert_raise Mongo::ConnectionFailure do
      storage = StorageMongo.instance(true)
    end

    ## it should not blow when we provide backup servers. 2 fakes and one real.

    configuration.mongo.servers = ["localhost:9090", "localhost:9092", StorageMongo::DEFAULT_SERVER]
    configuration.mongo.db = StorageMongo::DEFAULT_DATABASE

    storage = StorageMongo.instance(true)
    assert_not_nil storage
    assert_equal [storage.client.host,storage.client.port].join(":"), StorageMongo::DEFAULT_SERVER
  end

  test '#get ' do
    timestamp    = Time.utc(2013, 07,03)
    value        = 20
    conditions   = { metric: "8001", service: "1001" }
    expected_doc = { "day" => value, "hour" => nil, "minute" => nil }
    Mongo::Collection.any_instance.expects(:find_one).returns(expected_doc).times(1)

    assert_equal value, @storage.get(:day, timestamp, conditions)
  end

  test '#prepare_batch returns a batch with a document extracted from redis key' do
    key   = "stats/{service:1001}/metric:8001/day:20130703"
    value = 20

    expected_batch = {
      "daily" => {
        key => {
          metadata: {
            timestamp: Time.utc(2013, 07, 03),
            service:   "1001",
            metric:   "8001",
          },
          values: {
            "day" => value,
          }
        }
      }
    }
    assert_equal({}, @storage.batch)
    @storage.prepare_batch(key, value)
    assert_equal expected_batch, @storage.batch
  end

  test '#execute_batch should update mongodb data and clear the batch' do
    collection = mock('collection')
    collection.expects(:update).returns(true).times(1)
    Mongo::DB.any_instance.expects(:collection).with('daily').returns(collection).times(1)
    key   = "stats/{service:1001}/metric:8001/day:20130703"
    value = 20

    assert_equal({}, @storage.batch)
    @storage.prepare_batch(key, value)
    assert_not_equal({}, @storage.batch)

    @storage.execute_batch
    assert_equal({}, @storage.batch)
  end
end
