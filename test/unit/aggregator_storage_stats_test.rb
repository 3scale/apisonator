require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class AggregatorStorageStatsTest < Test::Unit::TestCase
  include TestHelpers::StorageKeys
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Sequences
  include TestHelpers::Fixtures
  include Backend::StorageHelpers

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb
    seed_data

    Stats::Storage.enable!
    Memoizer.reset!

    Resque.reset!
    Memoizer.reset!

    # I noticed that there are a bunch of variables that are not initialized.
    # The tests seem to run OK, but let's give them a value. For our sanity.
    @provider_key = 'test_provider_key'
    @plan_id = 'test_plan_id'
    @plan_name = 'test_plan_name'
    @metric_id = 'test_metric_id'
  end

  def stats_bucket_size
    Stats::Aggregator.send(:stats_bucket_size)
  end

  def bucket_storage
    Stats::Aggregator.send(:bucket_storage)
  end

  test 'process increments_all_stats_counters' do
    Stats::Aggregator.process([transaction_with_response_code])

    assert_equal '1', @storage.get(service_key(1001, 3001, :month, '20100501'))
    assert_equal '1', @storage.get(response_code_key(1001, '200', :month, '20100501'))
    assert_equal '1', @storage.get(response_code_key(1001, '2XX', :month, '20100501'))

    assert_equal '1', @storage.get(service_key(1001, 3001, :day, '20100507'))
    assert_equal '1', @storage.get(response_code_key(1001, '200', :day, '20100507'))
    assert_equal '1', @storage.get(response_code_key(1001, '2XX', :day, '20100507'))

    assert_equal '1', @storage.get(service_key(1001, 3001, :hour, '2010050713'))
    assert_equal '1', @storage.get(response_code_key(1001, '200', :hour, '2010050713'))
    assert_equal '1', @storage.get(response_code_key(1001, '2XX', :hour, '2010050713'))

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :year, '20100101'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '200', :year, '20100101'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '2XX', :year, '20100101'))

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :month, '20100501'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '200', :month, '20100501'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '2XX', :month, '20100501'))

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :day, '20100507'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '200', :day, '20100507'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '2XX', :day, '20100507'))

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :hour, '2010050713'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '200', :hour, '2010050713'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '2XX', :hour, '2010050713'))
  end


  test 'aggregates response codes incrementing 2XX for unknown 209 response'  do
    Stats::Aggregator.process([transaction_with_response_code(209)])
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '2XX', :hour, '2010050713'))
    assert_equal nil, @storage.get(app_response_code_key(1001, 2001, '209', :hour, '2010050713'))
  end

  test 'when storage stats is disabled nothing gets logged' do
    Stats::Storage.disable!
    Memoizer.reset! # the flag to know if storage stats is enabled is memoized

    Stats::Aggregator.process(Array.new(10, default_transaction))
    assert_equal 0, bucket_storage.pending_buckets_size
  end

  test 'delete all buckets and keys' do
    timestamp = Time.now.utc - 1000
    n_buckets = 5

    n_buckets.times do
      Timecop.freeze(timestamp) do
        Stats::Aggregator.process([default_transaction])
      end

      timestamp += stats_bucket_size
    end

    assert_equal n_buckets, @storage.keys('{stats_bucket}:*').size
    assert_equal n_buckets, Stats::BucketStorage.new(@storage).pending_buckets_size

    Stats::BucketStorage.new(@storage).delete_all_buckets_and_keys(silent: true)

    assert_equal 0, @storage.keys('{stats_bucket}:*').size
    assert_equal 0, Stats::BucketStorage.new(@storage).pending_buckets_size
  end

  test 'process updates application set' do
    Stats::Aggregator.process([default_transaction])

    assert_equal ['2001'], @storage.smembers('stats/{service:1001}/cinstances')
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

    assert ttl >  0
    assert ttl <= 180
  end

  test 'does not open a new stats buckets when the limit has been exceeded' do
    n_buckets = Stats::Aggregator.const_get(:MAX_BUCKETS) + 1
    mocked_bucket_storage = Object.new
    mocked_bucket_storage.define_singleton_method(:pending_buckets_size) { n_buckets }
    Stats::Aggregator.stubs(:bucket_storage).returns(mocked_bucket_storage)
    Stats::Aggregator.logger.stubs(:info)

    Stats::Aggregator.expects(:prepare_stats_buckets).never
    Stats::Aggregator.process([default_transaction])
  end

  test 'writes log when the limit has been exceeded' do
    n_buckets = Stats::Aggregator.const_get(:MAX_BUCKETS) + 1
    mocked_bucket_storage = Object.new
    mocked_bucket_storage.define_singleton_method(:pending_buckets_size) { n_buckets }
    Stats::Aggregator.stubs(:bucket_storage).returns(mocked_bucket_storage)

    Stats::Aggregator.logger.expects(:info).with(Stats::Aggregator.const_get(:MAX_BUCKETS_CREATED_MSG))
    Stats::Aggregator.process([default_transaction])
  end

  test 'disables bucket storage if buckets limit has been exceeded' do
    n_buckets = Stats::Aggregator.const_get(:MAX_BUCKETS) + 1
    mocked_bucket_storage = Object.new
    mocked_bucket_storage.define_singleton_method(:pending_buckets_size) { n_buckets }
    Stats::Aggregator.stubs(:bucket_storage).returns(mocked_bucket_storage)
    Stats::Aggregator.logger.stubs(:info)

    Stats::Aggregator.process([default_transaction])

    Memoizer.reset! # because Stats::Storage.enabled? is memoized
    assert_false Stats::Storage.enabled?
    assert_true Stats::Storage.last_disable_was_emergency?
  end

  test 'does not disable bucket storage if already disabled even if bucket limit is exceeded' do
    Stats::Storage.disable!

    Stats::Storage.expects(:disable!).never
    Stats::Aggregator.process([default_transaction])
  end

  test 'does not store buckets if the option was disabled manually' do
    Stats::Storage.disable!
    Stats::Aggregator.process([default_transaction])

    assert_equal 0, bucket_storage.pending_buckets_size
  end

  test 'does not store buckets if option disabled because an emergency and pending buckets > 0' do
    keys = ['key1', 'key2']
    bucket = '20170102120000'
    bucket_storage.put_in_bucket(keys, bucket)

    Stats::Storage.disable!(true)
    Stats::Aggregator.process([default_transaction])

    assert_equal({ bucket => keys.size }, bucket_storage.pending_keys_by_bucket)
  end

  test 'stores buckets if option disabled because an emergency and there are no pending buckets' do
    # No pending buckets at the start of the test

    Stats::Storage.disable!(true)
    Stats::Aggregator.process([default_transaction])

    assert_equal 1, bucket_storage.pending_buckets_size
  end

  test 're-enables bucket storage if disabled because emergency and there are no pending buckets' do
    # No pending buckets at the start of the test

    Stats::Storage.disable!(true)
    Stats::Aggregator.process([default_transaction])
    Memoizer.reset! # because Stats::Storage.enabled? is memoized

    assert_true Stats::Storage.enabled?
  end
end
