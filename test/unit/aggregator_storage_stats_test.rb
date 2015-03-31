require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require_relative '../../lib/3scale/backend/stats/tasks'

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
    Stats::Storage.activate!

    @storage_stats = Stats::Storage.instance(true)
    @storage_stats.drop_all_series

    Resque.reset!
    Memoizer.reset!

    reset_aggregator_prior_bucket!

    ## stubbing the airbreak, not working on tests
    Airbrake.stubs(:notify).returns(true)
  end

  def stats_bucket_size
    Stats::Aggregator.send(:stats_bucket_size)
  end

  test 'Stats jobs get properly enqueued' do
    assert_equal 0, Resque.queue(:main).length + Resque.queue(:stats).length

    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45)) do
      Stats::Aggregator.process([default_transaction])
    end
    assert_equal 0, Resque.queue(:main).length + Resque.queue(:stats).length

    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + (stats_bucket_size / 2).to_i)) do
      Stats::Aggregator.process([default_transaction])
    end
    assert_equal 0, Resque.queue(:main).length + Resque.queue(:stats).length

    ## antoher time bucket has elapsed

    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + (stats_bucket_size * 1.5).to_i)) do
      Stats::Aggregator.process([default_transaction])
    end
    assert_equal 1, Resque.queue(:main).length + Resque.queue(:stats).length

    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + (stats_bucket_size * 1.9).to_i)) do
      Stats::Aggregator.process([default_transaction])
    end

    assert_equal 1, Resque.queue(:main).length + Resque.queue(:stats).length

    ## antoher time bucket has elapsed

    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + (stats_bucket_size * 2).to_i)) do
      Stats::Aggregator.process([default_transaction])
    end
    assert_equal 2, Resque.queue(:main).length + Resque.queue(:stats).length
  end

  test 'benchmark check, not a real failure if happens' do
    cont = 1000

    t = Time.now
    timestamp = default_transaction_timestamp

    cont.times do
      Stats::Aggregator.process([default_transaction])
    end

    Stats::Tasks.schedule_one_stats_job
    Resque.run!

    assert_equal 0, Stats::Info.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length

    time_with_storage_stats = Time.now - t

    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :month,  '20100501'))
    assert_equal cont, @storage_stats.get(1001, 3001, :month, timestamp)

    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :day,    '20100507'))
    assert_equal cont, @storage_stats.get(1001, 3001, :day, timestamp)

    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :hour,   '2010050713'))
    assert_equal cont, @storage_stats.get(1001, 3001, :hour, timestamp)

    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :year,   '20100101'))
    assert_equal cont, @storage_stats.get(1001, 3001, :year, timestamp, application: 2001)

    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :month,  '20100501'))
    assert_equal cont, @storage_stats.get(1001, 3001, :month, timestamp, application: 2001)

    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :day,  '20100507'))
    assert_equal cont, @storage_stats.get(1001, 3001, :day, timestamp, application: 2001)

    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal cont, @storage_stats.get(1001, 3001, :hour, timestamp, application: 2001)

    @storage = Storage.instance(true)
    @storage.flushdb
    Memoizer.reset!
    seed_data

    @storage_stats = Stats::Storage.instance(true)
    @storage_stats.drop_all_series

    assert_equal nil, @storage_stats.get(1001, 3001, :month, timestamp)

    t = Time.now

    cont.times do
      Stats::Aggregator.process([default_transaction])
    end

    Stats::Tasks.schedule_one_stats_job
    Resque.run!

    assert_equal 0, Stats::Info.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length

    time_without_storage_stats = Time.now - t

    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :month,  '20100501'))
    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :day,    '20100507'))
    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :hour,   '2010050713'))
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :year,   '20100101'))
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :month,  '20100501'))
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :day,    '20100507'))
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))

    good_enough = time_with_storage_stats < time_without_storage_stats * 1.5

    unless good_enough
      puts "\nwith    storage stats: #{time_with_storage_stats}s"
      puts "without storage stats: #{time_without_storage_stats}s\n"
    end

    assert_equal true, good_enough
  end

  test 'process increments_all_stats_counters' do
    timestamp = default_transaction_timestamp
    Stats::Aggregator.process([transaction_with_response_code])

    assert_equal 0, Resque.queue(:main).length  + Resque.queue(:stats).length
    Stats::Tasks.schedule_one_stats_job
    assert_equal 1, Resque.queue(:main).length + Resque.queue(:stats).length
    Resque.run!
    assert_equal 0, Resque.queue(:main).length + Resque.queue(:stats).length

    assert_equal '1', @storage.get(service_key(1001, 3001, :month,  '20100501'))
    assert_equal '1', @storage.get(response_code_key(1001, '200', :month,  '20100501'))
    assert_equal '1', @storage.get(response_code_key(1001, '2XX', :month,  '20100501'))
    assert_equal 1, @storage_stats.get(1001, 3001, :month, timestamp)

    assert_equal '1', @storage.get(service_key(1001, 3001, :day,    '20100507'))
    assert_equal '1', @storage.get(response_code_key(1001, '200', :day,    '20100507'))
    assert_equal '1', @storage.get(response_code_key(1001, '2XX', :day,    '20100507'))
    assert_equal 1, @storage_stats.get(1001, 3001, :day, timestamp)

    assert_equal '1', @storage.get(service_key(1001, 3001, :hour,   '2010050713'))
    assert_equal '1', @storage.get(response_code_key(1001, '200', :hour,   '2010050713'))
    assert_equal '1', @storage.get(response_code_key(1001, '2XX', :hour,   '2010050713'))
    assert_equal 1, @storage_stats.get(1001, 3001, :hour, timestamp)

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :year,   '20100101'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '200', :year,   '20100101'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '2XX', :year,   '20100101'))
    assert_equal 1, @storage_stats.get(1001, 3001, :year, timestamp, application: 2001)

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :month,  '20100501'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '200', :month,  '20100501'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '2XX', :month,  '20100501'))
    assert_equal 1, @storage_stats.get(1001, 3001, :month, timestamp, application: 2001)

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :day,    '20100507'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '200', :day,    '20100507'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '2XX', :day,    '20100507'))
    assert_equal 1, @storage_stats.get(1001, 3001, :day, timestamp, application: 2001)

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '200', :hour,   '2010050713'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '2XX', :hour,   '2010050713'))
    assert_equal 1, @storage_stats.get(1001, 3001, :hour, timestamp, application: 2001)
  end


  test 'aggregates response codes incrementing 2XX for unknown 209 response '  do
    timestamp = default_transaction_timestamp
    transaction_with_unknown_response_code = transaction_with_response_code(209)
    Stats::Aggregator.process([transaction_with_unknown_response_code])

    assert_equal 0, Resque.queue(:main).length  + Resque.queue(:stats).length
    Stats::Tasks.schedule_one_stats_job
    assert_equal 1, Resque.queue(:main).length + Resque.queue(:stats).length
    Resque.run!
    assert_equal 0, Resque.queue(:main).length + Resque.queue(:stats).length
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '2XX', :hour,   '2010050713'))
    assert_equal nil, @storage.get(app_response_code_key(1001, 2001, '209', :hour,   '2010050713'))
  end

  test 'aggregate takes into account setting the counter value ok' do
    timestamp = default_transaction_timestamp

    Stats::Aggregator.process(Array.new(10, default_transaction))
    Stats::Tasks.schedule_one_stats_job
    Resque.run!

    assert_equal 10, @storage_stats.get(1001, 3001, :hour, timestamp, application: 2001)

    Stats::Aggregator.process([transaction_with_set_value])

    Stats::Tasks.schedule_one_stats_job
    Resque.run!

    assert_equal 665, @storage_stats.get(1001, 3001, :hour, timestamp, application: 2001)

    Stats::Aggregator.process([default_transaction])

    Stats::Tasks.schedule_one_stats_job
    Resque.run!

    assert_equal 666, @storage_stats.get(1001, 3001, :hour, timestamp, application: 2001)
  end

  test 'direct test of get_old_buckets_to_process' do
    ## this should go as unit test of StatsBatcher
    @storage.zadd(Stats::Keys.changed_keys_key, "20121010102100", "20121010102100")
    assert_equal [], Stats::Info.get_old_buckets_to_process("20121010102100")

    assert_equal ["20121010102100"], Stats::Info.get_old_buckets_to_process("20121010102120")

    assert_equal [], Stats::Info.get_old_buckets_to_process("20121010102120")

    @storage.del(Stats::Keys.changed_keys_key)

    100.times do |i|
      @storage.zadd(Stats::Keys.changed_keys_key, i, i.to_s)
    end

    assert_equal [], Stats::Info.get_old_buckets_to_process("0")

    v = Stats::Info.get_old_buckets_to_process("1")
    assert_equal v, ["0"]

    v = Stats::Info.get_old_buckets_to_process("1")
    assert_equal [], v

    v = Stats::Info.get_old_buckets_to_process("2")
    assert_equal v, ["1"]

    v = Stats::Info.get_old_buckets_to_process("2")
    assert_equal [], v

    v = Stats::Info.get_old_buckets_to_process("11")
    assert_equal 9, v.size
    assert_equal %w(2 3 4 5 6 7 8 9 10), v

    v = Stats::Info.get_old_buckets_to_process
    assert_equal 89, v.size

    v = Stats::Info.get_old_buckets_to_process
    assert_equal [], v
  end

  test 'concurrency test on get_old_buckets_to_process' do
    ## this should go as unit test of StatsBatcher
    100.times do |i|
      @storage.zadd(Stats::Keys.changed_keys_key, i, i.to_s)
    end

    10.times do |i|
      threads = []
      cont = 0

      20.times do
        threads << Thread.new do
          r = Redis.new(host: '127.0.0.1', port: 22121)
          v = Stats::Info.get_old_buckets_to_process(((i + 1) * 10).to_s, r)

          assert(v.size == 0 || v.size == 10)

          cont += 1 if v.size == 10
        end
      end

      threads.each(&:join)

      assert_equal 1, cont
    end
  end

  test 'bucket keys are properly assigned' do
    timestamp  = Time.now.utc - 1000

    assert_equal 0, Stats::Info.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length

    5.times do |cont|
      bucket_key = timestamp.beginning_of_bucket(stats_bucket_size).to_not_compact_s

      Timecop.freeze(timestamp) do
        Stats::Aggregator.process([default_transaction])
      end

      assert_equal cont + 1, Stats::Info.pending_buckets.size

      assert Stats::Info.pending_buckets.member?(bucket_key)
      assert_equal cont, Resque.queue(:main).length + Resque.queue(:stats).length

      timestamp += stats_bucket_size
    end

    assert_equal 5, Stats::Info.pending_buckets.size
    assert_equal 0, Stats::Info.failed_buckets.size

    sorted_set = Stats::Info.pending_buckets.sort

    4.times do |i|
      buckets = Stats::Info.get_old_buckets_to_process(sorted_set[i + 1])
      assert_equal 1, buckets.size
      assert_equal sorted_set[i], buckets.first
    end

    assert_equal 1, Stats::Info.pending_buckets.size
    buckets = Stats::Info.get_old_buckets_to_process
    assert_equal 1, buckets.size
    assert_equal sorted_set[4], buckets.first
  end

  test 'failed cql batches get stored into redis and processed properly afterwards' do
    metrics_timestamp = default_transaction_timestamp

    ## first one ok,
    Stats::Aggregator.process([default_transaction])

    assert_equal 1, Stats::Info.pending_buckets.size
    Stats::Tasks.schedule_one_stats_job
    Resque.run!
    assert_equal 0, Stats::Info.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Stats::Info.failed_buckets.size

    assert_equal '1', @storage.get(service_key(1001, 3001, :month, '20100501'))
    assert_equal 1, @storage_stats.get(1001, 3001, :month, metrics_timestamp)

    ## on the second on we stub the storage_stats to simulate a network error or storage stats down

    @storage_stats.stubs(:write_events).raises(Exception.new('bang!'))

    timestamp = Time.now.utc - 1000

    5.times do
      Timecop.freeze(timestamp) do
        Stats::Aggregator.process([default_transaction])
      end

      timestamp += stats_bucket_size
    end

    ## failed_buckets is 0 because nothing has been tried and hence failed yet
    assert_equal 0, Stats::Info.failed_buckets.size
    assert_equal 0, Stats::Info.failed_buckets_at_least_once.size
    assert_equal 5, Stats::Info.pending_buckets.size

    Stats::Tasks.schedule_one_stats_job
    Resque.run!
    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Resque.queue(:stats).length

    ## buckets went to the failed state
    assert_equal 0, Stats::Info.pending_buckets.size
    assert_equal 5, Stats::Info.failed_buckets.size
    assert_equal 5, Stats::Info.failed_buckets_at_least_once.size

    ## remove the stubbing
    @storage_stats = Stats::Storage.instance(true)

    assert_equal '6', @storage.get(service_key(1001, 3001, :month, '20100501'))
    assert_equal 1, @storage_stats.get(1001, 3001, :month, metrics_timestamp)

    ## now let's process the failed, one by one...

    v = Stats::Info.failed_buckets
    Stats::Storage.save_changed_keys(v.first)

    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Stats::Info.pending_buckets.size
    assert_equal 4, Stats::Info.failed_buckets.size
    assert_equal 5, Stats::Info.failed_buckets_at_least_once.size

    assert_equal '6', @storage.get(service_key(1001, 3001, :month, '20100501'))
    assert_equal 6, @storage_stats.get(1001, 3001, :month, metrics_timestamp)

    ## or altogether

    v = Stats::Info.failed_buckets
    v.each do |bucket|
      Stats::Storage.save_changed_keys(bucket)
    end

    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Stats::Info.pending_buckets.size
    assert_equal 0, Stats::Info.failed_buckets.size
    assert_equal 5, Stats::Info.failed_buckets_at_least_once.size

    assert_equal '6', @storage.get(service_key(1001, 3001, :month, '20100501'))
    assert_equal 6, @storage_stats.get(1001, 3001, :month, metrics_timestamp)
  end

  test 'aggregate takes into account setting the counter value in the case of failed batches' do
    @storage_stats.stubs(:write_events).raises(Exception.new('bang!'))
    @storage_stats.stubs(:get).raises(Exception.new('bang!'))

    timestamp = default_transaction_timestamp

    Stats::Aggregator.process(Array.new(10, default_transaction))
    Stats::Tasks.schedule_one_stats_job
    Resque.run!

    Stats::Aggregator.process([transaction_with_set_value])
    Stats::Tasks.schedule_one_stats_job
    Resque.run!

    Stats::Aggregator.process([default_transaction])
    Stats::Tasks.schedule_one_stats_job
    Resque.run!

    ## it failed for storage stats

    @storage_stats = Stats::Storage.instance(true)

    assert_equal '666', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal nil, @storage_stats.get(1001, 3001, :hour, timestamp, application: 2001)

    assert_equal 0, Stats::Info.pending_buckets.size
    assert_equal 1, Stats::Info.failed_buckets.size
    assert_equal 1, Stats::Info.failed_buckets_at_least_once.size

    v = Stats::Info.failed_buckets
    Stats::Storage.save_changed_keys(v.first)

    assert_equal '666', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 666, @storage_stats.get(1001, 3001, :hour, timestamp, application: 2001)
  end

  test 'when storage stats is deactivated buckets are filled but nothing gets saved' do
    Stats::Storage.deactivate!

    Stats::Aggregator.process(Array.new(10, default_transaction))

    assert_equal 0, Resque.queue(:main).length
    assert_equal 1, Stats::Info.pending_buckets.size

    Stats::Tasks.schedule_one_stats_job
    Resque.run!

    assert_equal 0, Resque.queue(:main).length
    assert_equal 1, Stats::Info.pending_buckets.size

    Stats::Storage.activate!

    Stats::Tasks.schedule_one_stats_job
    Resque.run!

    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Stats::Info.pending_buckets.size
  end

  test 'when storage stats is disabled nothing gets logged' do
    Stats::Storage.disable!
    ## the flag to know if storage stats is enabled is memoized
    Memoizer.reset!

    Stats::Aggregator.process(Array.new(10, default_transaction))

    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Stats::Info.pending_buckets.size

    Stats::Tasks.schedule_one_stats_job
    Resque.run!

    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Stats::Info.pending_buckets.size
  end

  test 'when storage stats is disabled, storage stats does not have to be up and running, but stats get lost during the disabling period' do
    timestamp = default_transaction_timestamp
    v = []
    Timecop.freeze(Time.utc(2010, 5, 7, 13, 23, 33)) do
      10.times { v << default_transaction }
    end

    Stats::Storage.disable!
    ## the flag to know if storage stats is enabled is memoized
    Memoizer.reset!

    v.each do |item|
      Stats::Aggregator.process([item])
    end

    Stats::Info.pending_buckets.size.times do
      Stats::Tasks.schedule_one_stats_job
    end
    Resque.run!

    ## because storage stats is disabled nothing blows and nothing get logged, it's
    ## like the storage stats code never existed
    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Stats::Info.pending_buckets.size

    assert_equal '10', @storage.get(application_key(1001, 2001, 3001, :hour, '2010050713'))
    assert_equal nil, @storage_stats.get(1001, 3001, :hour, timestamp, application: 2001)

    Stats::Storage.enable!
    ## the flag to know if storage stats is enabled is memoized
    Memoizer.reset!
    v.each do |item|
      Stats::Aggregator.process([item])
    end
    assert_equal 1, Stats::Info.pending_buckets.size

    Stats::Info.pending_buckets.size.times do
      Stats::Tasks.schedule_one_stats_job
    end
    Resque.run!

    assert_equal 0, Stats::Info.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length

    assert_equal '20', @storage.get(application_key(1001, 2001, 3001, :hour, '2010050713'))
    assert_equal 20, @storage_stats.get(1001, 3001, :hour, timestamp, application: 2001)
  end

  test 'when storage stats is deactivated, storage stats does not have to be up and running, but stats do NOT get lost during the deactivation period' do
    timestamp = default_transaction_timestamp

    v = Array.new(10, default_transaction)

    Stats::Storage.deactivate!

    v.each do |item|
      Stats::Aggregator.process([item])
    end

    assert_equal 1, Stats::Info.pending_buckets.size

    Stats::Tasks.schedule_one_stats_job
    Resque.run!

    ## because storage stats is deactivated nothing blows but it gets logged waiting for storage stats
    ## to be in place again
    assert_equal 0, Resque.queue(:main).length
    assert_equal 1, Stats::Info.pending_buckets.size

    assert_equal '10', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal nil, @storage_stats.get(1001, 3001, :hour, timestamp, application: 2001)

    Stats::Storage.activate!

    assert_equal 1, Stats::Info.pending_buckets.size

    sleep(stats_bucket_size)
    v.each do |item|
      Stats::Aggregator.process([item])
    end

    assert_equal 2, Stats::Info.pending_buckets.size

    Stats::Tasks.schedule_one_stats_job
    Resque.run!

    assert_equal 0, Stats::Info.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length

    assert_equal '20', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 20, @storage_stats.get(1001, 3001, :hour, timestamp, application: 2001)
  end

  test 'applications with end user plans (user_id) get recorded properly' do
    default_user_plan_id = next_id
    default_user_plan_name = "user plan mobile"
    timestamp = default_transaction_timestamp

    service = Service.save!(provider_key: @provider_key, id: next_id)
    Service.stubs(:load_by_id).returns(service)
    service.stubs :user_add

    service.user_registration_required = false
    service.default_user_plan_name = default_user_plan_name
    service.default_user_plan_id = default_user_plan_id
    service.save!

    application = Application.save(service_id:    service.id,
                                   id:            next_id,
                                   state:         :active,
                                   plan_id:       @plan_id,
                                   plan_name:     @plan_name,
                                   user_required: true)

    transaction = Transaction.new(service_id:     service.id,
                                  application_id: application.id,
                                  timestamp:      timestamp,
                                  usage:          { @metric_hits.id => 5 },
                                  user_id:        "user_id_xyz")

    Stats::Aggregator.process([transaction])

    Stats::Info.pending_buckets.size.times do
      Stats::Tasks.schedule_one_stats_job
    end
    Resque.run!

    assert_equal 0, Stats::Info.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length

    assert_equal '5', @storage.get(application_key(service.id, application.id, @metric_hits.id, :hour,   '2010050713'))
    assert_equal '5', @storage.get(application_key(service.id, application.id, @metric_hits.id, :month,   '20100501'))
    assert_equal '5', @storage.get(application_key(service.id, application.id, @metric_hits.id, :eternity))

    assert_equal '5', @storage.get(service_key(service.id, @metric_hits.id, :hour,   '2010050713'))
    assert_equal '5', @storage.get(service_key(service.id, @metric_hits.id, :month,   '20100501'))
    assert_equal '5', @storage.get(service_key(service.id, @metric_hits.id, :eternity))

    assert_equal '5', @storage.get(end_user_key(service.id, "user_id_xyz", @metric_hits.id, :hour,   '2010050713'))
    assert_equal '5', @storage.get(end_user_key(service.id, "user_id_xyz", @metric_hits.id, :month,   '20100501'))
    assert_equal '5', @storage.get(end_user_key(service.id, "user_id_xyz", @metric_hits.id, :eternity))

    assert_equal 5, @storage_stats.get(service.id, @metric_hits.id, :hour, timestamp, application: application.id)
    assert_equal 5, @storage_stats.get(service.id, @metric_hits.id, :month, timestamp, application: application.id)

    assert_equal 5, @storage_stats.get(service.id, @metric_hits.id, :hour, timestamp)
    assert_equal 5, @storage_stats.get(service.id, @metric_hits.id, :month, timestamp)

    assert_equal 5, @storage_stats.get(service.id, @metric_hits.id, :hour, timestamp, user: "user_id_xyz")
    assert_equal 5, @storage_stats.get(service.id, @metric_hits.id, :month, timestamp, user: "user_id_xyz")

    transaction = Transaction.new(service_id:     service.id,
                                  application_id: application.id,
                                  timestamp:      timestamp,
                                  usage:          { @metric_hits.id => 4 },
                                  user_id:        "another_user_id_xyz")

    Stats::Aggregator.process([transaction])

    Stats::Info.pending_buckets.size.times do
      Stats::Tasks.schedule_one_stats_job
    end
    Resque.run!

    assert_equal 0, Stats::Info.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length

    assert_equal '9', @storage.get(application_key(service.id, application.id, @metric_hits.id, :hour,   '2010050713'))
    assert_equal '9', @storage.get(application_key(service.id, application.id, @metric_hits.id, :month,   '20100501'))
    assert_equal '9', @storage.get(application_key(service.id, application.id, @metric_hits.id, :eternity))

    assert_equal '9', @storage.get(service_key(service.id, @metric_hits.id, :hour,   '2010050713'))
    assert_equal '9', @storage.get(service_key(service.id, @metric_hits.id, :month,   '20100501'))
    assert_equal '9', @storage.get(service_key(service.id, @metric_hits.id, :eternity))

    assert_equal '4', @storage.get(end_user_key(service.id, "another_user_id_xyz", @metric_hits.id, :hour,   '2010050713'))
    assert_equal '4', @storage.get(end_user_key(service.id, "another_user_id_xyz", @metric_hits.id, :month,   '20100501'))
    assert_equal '4', @storage.get(end_user_key(service.id, "another_user_id_xyz", @metric_hits.id, :eternity))

    assert_equal 9, @storage_stats.get(service.id, @metric_hits.id, :hour, timestamp, application: application.id)
    assert_equal 9, @storage_stats.get(service.id, @metric_hits.id, :month, timestamp, application: application.id)

    assert_equal 9, @storage_stats.get(service.id, @metric_hits.id, :hour, timestamp)
    assert_equal 9, @storage_stats.get(service.id, @metric_hits.id, :month, timestamp)

    assert_equal 4, @storage_stats.get(service.id, @metric_hits.id, :hour, timestamp, user: "another_user_id_xyz")
    assert_equal 4, @storage_stats.get(service.id, @metric_hits.id, :month, timestamp, user: "another_user_id_xyz")
  end


  test 'transactions with end_user plans (user_id) with response codes get properly aggregated' do
    default_user_plan_id = next_id
    default_user_plan_name = "user plan mobile"
    timestamp = default_transaction_timestamp

    service = Service.save!(provider_key: @provider_key, id: next_id)
    Service.stubs(:load_by_id).returns(service)
    service.stubs :user_add

    service.user_registration_required = false
    service.default_user_plan_name = default_user_plan_name
    service.default_user_plan_id = default_user_plan_id
    service.save!

    application = Application.save(service_id:    service.id,
                                   id:            next_id,
                                   state:         :active,
                                   plan_id:       @plan_id,
                                   plan_name:     @plan_name,
                                   user_required: true)

    transaction = Transaction.new(service_id:     service.id,
                                  application_id: application.id,
                                  timestamp:      timestamp,
                                  usage:          { @metric_hits.id => 1 },
                                  response_code: 200,
                                  user_id:        "user_id_xyz")

    Stats::Aggregator.process([transaction])

    Stats::Info.pending_buckets.size.times do
      Stats::Tasks.schedule_one_stats_job
    end
    Resque.run!

    assert_equal 0, Stats::Info.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length

    assert_equal '1', @storage.get(end_user_response_code_key(service.id, "user_id_xyz", '2XX', :hour,   '2010050713'))
    assert_equal '1', @storage.get(end_user_response_code_key(service.id, "user_id_xyz", '2XX', :month,   '20100501'))
    assert_equal '1', @storage.get(end_user_response_code_key(service.id, "user_id_xyz", '2XX', :eternity))
    assert_equal '1', @storage.get(end_user_response_code_key(service.id, "user_id_xyz", '200', :hour,   '2010050713'))
    assert_equal '1', @storage.get(end_user_response_code_key(service.id, "user_id_xyz", '200', :month,   '20100501'))
    assert_equal '1', @storage.get(end_user_response_code_key(service.id, "user_id_xyz", '200', :eternity))
  end

  test 'delete all buckets and keys' do
    @storage_stats.stubs(:write_events).raises(Exception.new('bang!'))
    @storage_stats.stubs(:get).raises(Exception.new('bang!'))

    timestamp = Time.now.utc - 1000

    5.times do
      Timecop.freeze(timestamp) do
        Stats::Aggregator.process([default_transaction])
      end

      timestamp += stats_bucket_size
    end

    ## failed_buckets is 0 because nothing has been tried and hence failed yet
    assert_equal 0, Stats::Info.failed_buckets.size
    assert_equal 5, Stats::Info.pending_buckets.size

    Stats::Tasks.schedule_one_stats_job
    Resque.run!
    assert_equal 0, Resque.queue(:main).length

    ## jobs did not do anything because storage stats connection failed
    assert_equal 0, Stats::Info.pending_buckets.size
    assert_equal 5, Stats::Info.failed_buckets_at_least_once.size
    assert_equal 5, Stats::Info.failed_buckets.size

    v = @storage.keys("keys_changed:*")
    assert_equal true, v.size > 0
    assert_equal 5, v.size

    v = @storage.keys("copied:*")
    assert_equal 0, v.size

    Stats::Tasks.delete_all_buckets_and_keys_only_as_rake!(silent: true)

    v = @storage.keys("copied:*")
    assert_equal 0, v.size

    v = @storage.keys("keys_changed:*")
    assert_equal 0, v.size

    assert_equal 0, Stats::Info.pending_buckets.size
    assert_equal 0, Stats::Info.failed_buckets.size
    assert_equal 0, Stats::Info.failed_buckets_at_least_once.size
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
end
