require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require_relative '../../lib/3scale/backend/aggregator/stats_tasks'

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

    StorageStats.enable!
    Memoizer.reset!
    StorageStats.activate!

    @storage_stats = StorageStats.instance(true)
    @storage_stats.drop_all_series

    Resque.reset!
    Memoizer.reset!

    Aggregator.reset_current_bucket!

    ## stubbing the airbreak, not working on tests
    Airbrake.stubs(:notify).returns(true)
  end

  def stats_bucket_size
    Aggregator.send(:stats_bucket_size)
  end

  def default_timestamp
    Time.utc(2010, 5, 7, 13, 23, 33)
  end

  def default_transaction
    {
      service_id:     1001,
      application_id: 2001,
      timestamp:      default_timestamp,
      usage:          { '3001' => 1 },
    }
  end

  def transaction_with_set_value
    default_transaction.merge(
      usage: { '3001' => '#665' },
    )
  end

  test 'Stats jobs get properly enqueued' do
    assert_equal 0, Resque.queue(:main).length + Resque.queue(:stats).length

    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45)) do
      Aggregator.aggregate_all([default_transaction])
    end
    assert_equal 0, Resque.queue(:main).length + Resque.queue(:stats).length

    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + (stats_bucket_size / 2).to_i)) do
      Aggregator.aggregate_all([default_transaction])
    end
    assert_equal 0, Resque.queue(:main).length + Resque.queue(:stats).length

    ## antoher time bucket has elapsed

    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + (stats_bucket_size * 1.5).to_i)) do
      Aggregator.aggregate_all([default_transaction])
    end
    assert_equal 1, Resque.queue(:main).length + Resque.queue(:stats).length

    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + (stats_bucket_size * 1.9).to_i)) do
      Aggregator.aggregate_all([default_transaction])
    end

    assert_equal 1, Resque.queue(:main).length + Resque.queue(:stats).length

    ## antoher time bucket has elapsed

    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + (stats_bucket_size * 2).to_i)) do
      Aggregator.aggregate_all([default_transaction])
    end
    assert_equal 2, Resque.queue(:main).length + Resque.queue(:stats).length
  end

  test 'Distribute stats job per service' do
    assert_equal 0, Resque.queue(:main).length + Resque.queue(:stats).length

    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45)) do
      Aggregator.aggregate_all([default_transaction])
    end
    assert_equal 0, Resque.queue(:main).length + Resque.queue(:stats).length

    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + (Aggregator.stats_bucket_size * 1.9).to_i)) do
      Aggregator.aggregate_all(
        [
          default_transaction,
          {
            service_id: 1002,
            application_id: 2002,
            timestamp: Time.utc(2010, 5, 7, 13, 23, 33),
            usage: { '3002' => 1 },
          }
        ])
    end
    assert_equal 2, Resque.queue(:main).length + Resque.queue(:stats).length

    jobs = Resque.queue(:stats).map { |raw_job| decode(raw_job) }
    assert_equal 1001, jobs[0][:args].first.split(":").first.to_i
    assert_equal 1002, jobs[1][:args].first.split(":").first.to_i
  end

  test 'benchmark check, not a real failure if happens' do
    cont = 1000

    t = Time.now
    timestamp = default_timestamp

    cont.times do
      Aggregator.aggregate_all([default_transaction])
    end

    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
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

    @storage_stats = StorageStats.instance(true)
    @storage_stats.drop_all_series

    assert_equal nil, @storage_stats.get(1001, 3001, :month, timestamp)

    t = Time.now

    cont.times do
      Aggregator.aggregate_all([default_transaction])
    end

    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
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

  test 'aggregate_all increments_all_stats_counters' do
    timestamp = default_timestamp
    Aggregator.aggregate_all([default_transaction])

    assert_equal 0, Resque.queue(:main).length  + Resque.queue(:stats).length
    Aggregator::StatsTasks.schedule_one_stats_job
    assert_equal 1, Resque.queue(:main).length + Resque.queue(:stats).length
    Resque.run!
    assert_equal 0, Resque.queue(:main).length + Resque.queue(:stats).length

    assert_equal '1', @storage.get(service_key(1001, 3001, :month,  '20100501'))
    assert_equal 1, @storage_stats.get(1001, 3001, :month, timestamp)

    assert_equal '1', @storage.get(service_key(1001, 3001, :day,    '20100507'))
    assert_equal 1, @storage_stats.get(1001, 3001, :day, timestamp)

    assert_equal '1', @storage.get(service_key(1001, 3001, :hour,   '2010050713'))
    assert_equal 1, @storage_stats.get(1001, 3001, :hour, timestamp)

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :year,   '20100101'))
    assert_equal 1, @storage_stats.get(1001, 3001, :year, timestamp, application: 2001)

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :month,  '20100501'))
    assert_equal 1, @storage_stats.get(1001, 3001, :month, timestamp, application: 2001)

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :day,    '20100507'))
    assert_equal 1, @storage_stats.get(1001, 3001, :day, timestamp, application: 2001)

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 1, @storage_stats.get(1001, 3001, :hour, timestamp, application: 2001)
  end

  test 'aggregate takes into account setting the counter value ok' do
    timestamp = default_timestamp

    Aggregator.aggregate_all(Array.new(10, default_transaction))
    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    assert_equal 10, @storage_stats.get(1001, 3001, :hour, timestamp, application: 2001)

    Aggregator.aggregate_all([transaction_with_set_value])

    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    assert_equal 665, @storage_stats.get(1001, 3001, :hour, timestamp, application: 2001)

    Aggregator.aggregate_all([default_transaction])

    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    assert_equal 666, @storage_stats.get(1001, 3001, :hour, timestamp, application: 2001)
  end

  test 'direct test of get_old_buckets_to_process' do
    ## this should go as unit test of StatsBatcher
    @storage.zadd(Aggregator::StatsKeys.changed_keys_key, "20121010102100", "20121010102100")
    assert_equal [], Aggregator::StatsInfo.get_old_buckets_to_process("20121010102100")

    assert_equal ["20121010102100"], Aggregator::StatsInfo.get_old_buckets_to_process("20121010102120")

    assert_equal [], Aggregator::StatsInfo.get_old_buckets_to_process("20121010102120")

    @storage.del(Aggregator::StatsKeys.changed_keys_key)

    100.times do |i|
      @storage.zadd(Aggregator::StatsKeys.changed_keys_key, i, i.to_s)
    end

    assert_equal [], Aggregator::StatsInfo.get_old_buckets_to_process("0")

    v = Aggregator::StatsInfo.get_old_buckets_to_process("1")
    assert_equal v, ["0"]

    v = Aggregator::StatsInfo.get_old_buckets_to_process("1")
    assert_equal [], v

    v = Aggregator::StatsInfo.get_old_buckets_to_process("2")
    assert_equal v, ["1"]

    v = Aggregator::StatsInfo.get_old_buckets_to_process("2")
    assert_equal [], v

    v = Aggregator::StatsInfo.get_old_buckets_to_process("11")
    assert_equal 9, v.size
    assert_equal %w(2 3 4 5 6 7 8 9 10), v

    v = Aggregator::StatsInfo.get_old_buckets_to_process
    assert_equal 89, v.size

    v = Aggregator::StatsInfo.get_old_buckets_to_process
    assert_equal [], v
  end

  test 'concurrency test on get_old_buckets_to_process' do
    ## this should go as unit test of StatsBatcher
    100.times do |i|
      @storage.zadd(Aggregator::StatsKeys.changed_keys_key, i, i.to_s)
    end

    10.times do |i|
      threads = []
      cont = 0

      20.times do
        threads << Thread.new do
          r = Redis.new(host: '127.0.0.1', port: 22121)
          v = Aggregator::StatsInfo.get_old_buckets_to_process(((i + 1) * 10).to_s, r)

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
    service_id = 1001

    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length

    5.times do |cont|
      bucket_key = timestamp.beginning_of_bucket(stats_bucket_size).to_not_compact_s

      Timecop.freeze(timestamp) do
        Aggregator.aggregate_all([default_transaction])
      end

      assert_equal cont + 1, Aggregator::StatsInfo.pending_buckets.size

      assert Aggregator::StatsInfo.pending_buckets.member?("#{service_id}:#{bucket_key}")
      assert_equal cont, Resque.queue(:main).length + Resque.queue(:stats).length

      timestamp += stats_bucket_size
    end

    assert_equal 5, Aggregator::StatsInfo.pending_buckets.size
    assert_equal 0, Aggregator::StatsInfo.failed_buckets.size

    sorted_set = Aggregator::StatsInfo.pending_buckets.sort

    4.times do |i|
      buckets = Aggregator::StatsInfo.get_old_buckets_to_process(sorted_set[i + 1])
      assert_equal 1, buckets.size
      assert_equal sorted_set[i], buckets.first
    end

    assert_equal 1, Aggregator::StatsInfo.pending_buckets.size
    buckets = Aggregator::StatsInfo.get_old_buckets_to_process
    assert_equal 1, buckets.size
    assert_equal sorted_set[4], buckets.first
  end

  test 'failed cql batches get stored into redis and processed properly afterwards' do
    metrics_timestamp = default_timestamp

    ## first one ok,
    Aggregator.aggregate_all([default_transaction])

    assert_equal 1, Aggregator::StatsInfo.pending_buckets.size
    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!
    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Aggregator::StatsInfo.failed_buckets.size

    assert_equal '1', @storage.get(service_key(1001, 3001, :month, '20100501'))
    assert_equal 1, @storage_stats.get(1001, 3001, :month, metrics_timestamp)

    ## on the second on we stub the storage_stats to simulate a network error or storage stats down

    @storage_stats.stubs(:write_events).raises(Exception.new('bang!'))

    timestamp = Time.now.utc - 1000

    5.times do
      Timecop.freeze(timestamp) do
        Aggregator.aggregate_all([default_transaction])
      end

      timestamp += stats_bucket_size
    end

    ## failed_buckets is 0 because nothing has been tried and hence failed yet
    assert_equal 0, Aggregator::StatsInfo.failed_buckets.size
    assert_equal 0, Aggregator::StatsInfo.failed_buckets_at_least_once.size
    assert_equal 5, Aggregator::StatsInfo.pending_buckets.size

    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!
    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Resque.queue(:stats).length

    ## buckets went to the failed state
    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
    assert_equal 5, Aggregator::StatsInfo.failed_buckets.size
    assert_equal 5, Aggregator::StatsInfo.failed_buckets_at_least_once.size

    ## remove the stubbing
    @storage_stats = StorageStats.instance(true)

    assert_equal '6', @storage.get(service_key(1001, 3001, :month, '20100501'))
    assert_equal 1, @storage_stats.get(1001, 3001, :month, metrics_timestamp)

    ## now let's process the failed, one by one...

    v = Aggregator::StatsInfo.failed_buckets
    StorageStats.save_changed_keys(v.first)

    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
    assert_equal 4, Aggregator::StatsInfo.failed_buckets.size
    assert_equal 5, Aggregator::StatsInfo.failed_buckets_at_least_once.size

    assert_equal '6', @storage.get(service_key(1001, 3001, :month, '20100501'))
    assert_equal 6, @storage_stats.get(1001, 3001, :month, metrics_timestamp)

    ## or altogether

    v = Aggregator::StatsInfo.failed_buckets
    v.each do |bucket|
      StorageStats.save_changed_keys(bucket)
    end

    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
    assert_equal 0, Aggregator::StatsInfo.failed_buckets.size
    assert_equal 5, Aggregator::StatsInfo.failed_buckets_at_least_once.size

    assert_equal '6', @storage.get(service_key(1001, 3001, :month, '20100501'))
    assert_equal 6, @storage_stats.get(1001, 3001, :month, metrics_timestamp)
  end

  test 'aggregate takes into account setting the counter value in the case of failed batches' do
    @storage_stats.stubs(:write_events).raises(Exception.new('bang!'))
    @storage_stats.stubs(:get).raises(Exception.new('bang!'))

    timestamp = default_timestamp

    Aggregator.aggregate_all(Array.new(10, default_transaction))
    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    Aggregator.aggregate_all([transaction_with_set_value])
    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    Aggregator.aggregate_all([default_transaction])
    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    ## it failed for storage stats

    @storage_stats = StorageStats.instance(true)

    assert_equal '666', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal nil, @storage_stats.get(1001, 3001, :hour, timestamp, application: 2001)

    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
    assert_equal 1, Aggregator::StatsInfo.failed_buckets.size
    assert_equal 1, Aggregator::StatsInfo.failed_buckets_at_least_once.size

    v = Aggregator::StatsInfo.failed_buckets
    StorageStats.save_changed_keys(v.first)

    assert_equal '666', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 666, @storage_stats.get(1001, 3001, :hour, timestamp, application: 2001)
  end

  test 'when storage stats is deactivated buckets are filled but nothing gets saved' do
    StorageStats.deactivate!

    Aggregator.aggregate_all(Array.new(10, default_transaction))

    assert_equal 0, Resque.queue(:main).length
    assert_equal 1, Aggregator::StatsInfo.pending_buckets.size

    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    assert_equal 0, Resque.queue(:main).length
    assert_equal 1, Aggregator::StatsInfo.pending_buckets.size

    StorageStats.activate!

    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
  end

  test 'when storage stats is disabled nothing gets logged' do
    StorageStats.disable!
    ## the flag to know if storage stats is enabled is memoized
    Memoizer.reset!

    Aggregator.aggregate_all(Array.new(10, default_transaction))

    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size

    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
  end

  test 'when storage stats is disabled, storage stats does not have to be up and running, but stats get lost during the disabling period' do
    timestamp = default_timestamp
    v = []
    Timecop.freeze(Time.utc(2010, 5, 7, 13, 23, 33)) do
      10.times { v << default_transaction }
    end

    StorageStats.disable!
    ## the flag to know if storage stats is enabled is memoized
    Memoizer.reset!

    v.each do |item|
      Aggregator.aggregate_all([item])
    end

    Aggregator::StatsInfo.pending_buckets.size.times do
      Aggregator::StatsTasks.schedule_one_stats_job
    end
    Resque.run!

    ## because storage stats is disabled nothing blows and nothing get logged, it's
    ## like the storage stats code never existed
    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size

    assert_equal '10', @storage.get(application_key(1001, 2001, 3001, :hour, '2010050713'))
    assert_equal nil, @storage_stats.get(1001, 3001, :hour, timestamp, application: 2001)

    StorageStats.enable!
    ## the flag to know if storage stats is enabled is memoized
    Memoizer.reset!
    v.each do |item|
      Aggregator.aggregate_all([item])
    end
    assert_equal 1, Aggregator::StatsInfo.pending_buckets.size

    Aggregator::StatsInfo.pending_buckets.size.times do
      Aggregator::StatsTasks.schedule_one_stats_job
    end
    Resque.run!

    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length

    assert_equal '20', @storage.get(application_key(1001, 2001, 3001, :hour, '2010050713'))
    assert_equal 20, @storage_stats.get(1001, 3001, :hour, timestamp, application: 2001)
  end

  test 'when storage stats is deactivated, storage stats does not have to be up and running, but stats do NOT get lost during the deactivation period' do
    timestamp = default_timestamp

    v = Array.new(10, default_transaction)

    StorageStats.deactivate!

    v.each do |item|
      Aggregator.aggregate_all([item])
    end

    assert_equal 1, Aggregator::StatsInfo.pending_buckets.size

    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    ## because storage stats is deactivated nothing blows but it gets logged waiting for storage stats
    ## to be in place again
    assert_equal 0, Resque.queue(:main).length
    assert_equal 1, Aggregator::StatsInfo.pending_buckets.size

    assert_equal '10', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal nil, @storage_stats.get(1001, 3001, :hour, timestamp, application: 2001)

    StorageStats.activate!

    assert_equal 1, Aggregator::StatsInfo.pending_buckets.size

    sleep(stats_bucket_size)
    v.each do |item|
      Aggregator.aggregate_all([item])
    end

    assert_equal 2, Aggregator::StatsInfo.pending_buckets.size

    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length

    assert_equal '20', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 20, @storage_stats.get(1001, 3001, :hour, timestamp, application: 2001)
  end

  test 'applications with end user plans (user_id) get recorded properly' do
    default_user_plan_id = next_id
    default_user_plan_name = "user plan mobile"
    timestamp = default_timestamp

    service = Service.save!(provider_key: @provider_key, id: next_id)
    #
    # TODO: Temporary stubs until we decouple Backend::User from Core::User
    Core::Service.stubs(:load_by_id).returns(service)
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

    Aggregator.aggregate_all([{ service_id:     service.id,
                                application_id: application.id,
                                timestamp:      timestamp,
                                usage:          { @metric_hits.id => 5 },
                                user_id:        "user_id_xyz" }])

    Aggregator::StatsInfo.pending_buckets.size.times do
      Aggregator::StatsTasks.schedule_one_stats_job
    end
    Resque.run!

    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
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

    Aggregator.aggregate_all([{ service_id:     service.id,
                                application_id: application.id,
                                timestamp:      timestamp,
                                usage:          { @metric_hits.id => 4 },
                                user_id:        "another_user_id_xyz" }])

    Aggregator::StatsInfo.pending_buckets.size.times do
      Aggregator::StatsTasks.schedule_one_stats_job
    end
    Resque.run!

    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
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

  test 'delete all buckets and keys' do
    @storage_stats.stubs(:write_events).raises(Exception.new('bang!'))
    @storage_stats.stubs(:get).raises(Exception.new('bang!'))

    timestamp = Time.now.utc - 1000

    5.times do
      Timecop.freeze(timestamp) do
        Aggregator.aggregate_all([default_transaction])
      end

      timestamp += stats_bucket_size
    end

    ## failed_buckets is 0 because nothing has been tried and hence failed yet
    assert_equal 0, Aggregator::StatsInfo.failed_buckets.size
    assert_equal 5, Aggregator::StatsInfo.pending_buckets.size

    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!
    assert_equal 0, Resque.queue(:main).length

    ## jobs did not do anything because storage stats connection failed
    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
    assert_equal 5, Aggregator::StatsInfo.failed_buckets_at_least_once.size
    assert_equal 5, Aggregator::StatsInfo.failed_buckets.size

    v = @storage.keys("keys_changed:*")
    assert_equal true, v.size > 0
    assert_equal 5, v.size

    v = @storage.keys("copied:*")
    assert_equal 0, v.size

    Aggregator::StatsTasks.delete_all_buckets_and_keys_only_as_rake!(silent: true)

    v = @storage.keys("copied:*")
    assert_equal 0, v.size

    v = @storage.keys("keys_changed:*")
    assert_equal 0, v.size

    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
    assert_equal 0, Aggregator::StatsInfo.failed_buckets.size
    assert_equal 0, Aggregator::StatsInfo.failed_buckets_at_least_once.size
  end

  test 'aggregate_all updates application set' do
    Aggregator.aggregate_all([default_transaction])

    assert_equal ['2001'], @storage.smembers("stats/{service:1001}/cinstances")
  end

  test 'aggregate_all does not update service set' do
    assert_no_change of: lambda { @storage.smembers('stats/services') } do
      Aggregator.aggregate_all([default_transaction])
    end
  end

  test 'aggregate_all sets expiration time for volatile keys' do
    Aggregator.aggregate_all([default_transaction])

    key = application_key('1001', '2001', '3001', :minute, 201005071323)
    ttl = @storage.ttl(key)

    assert_not_equal(-1, ttl)
    assert ttl >  0
    assert ttl <= 180
  end
end
