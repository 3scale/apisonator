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

    Resque.reset!
    Memoizer.reset!

    # I noticed that there are a bunch of variables that are not initialized.
    # The tests seem to run OK, but let's give them a value. For our sanity.
    @provider_key = 'test_provider_key'
    @plan_id = 'test_plan_id'
    @plan_name = 'test_plan_name'
    @metric_id = 'test_metric_id'
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
end
