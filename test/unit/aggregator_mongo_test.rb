require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require_relative '../../lib/3scale/backend/aggregator/stats_tasks'

class AggregatorMongoTest < Test::Unit::TestCase
  include TestHelpers::StorageKeys
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Sequences
  include TestHelpers::Fixtures
  include Backend::StorageHelpers

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb
    seed_data

    # all the test will have to disable the flag before finishing,
    ## in theory not needed since we always do flush, if not
    ## @storage.del("mongo_enabled")
    StorageStats.enable!
    ## the flag to know if mongo is enabled is memoized
    Memoizer.reset!
    StorageStats.activate!

    @storage_mongo = StorageMongo.instance(true)
    @storage_mongo.clear_collections

    Resque.reset!
    Memoizer.reset!

    Aggregator.reset_current_bucket!

    ## stubbing the airbreak, not working on tests
    Airbrake.stubs(:notify).returns(true)
  end

  test 'Stats jobs get properly enqueued' do
    assert_equal 0, Resque.queue(:main).length + Resque.queue(:stats).length

    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45)) do
      Aggregator.aggregate_all([{:service_id     => 1001,
                                :application_id => 2001,
                                :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                :usage          => {'3001' => 1}}])
    end
    assert_equal 0, Resque.queue(:main).length + Resque.queue(:stats).length

    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + (Aggregator.stats_bucket_size/2).to_i)) do
      Aggregator.aggregate_all([{:service_id     => 1001,
                                :application_id => 2001,
                                :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                :usage          => {'3001' => 1}}])
    end
    assert_equal 0, Resque.queue(:main).length + Resque.queue(:stats).length

    ## antoher time bucket has elapsed

    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + (Aggregator.stats_bucket_size*1.5).to_i)) do
      Aggregator.aggregate_all([{:service_id     => 1001,
                                :application_id => 2001,
                                :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                :usage          => {'3001' => 1}}])
    end
    assert_equal 1, Resque.queue(:main).length + Resque.queue(:stats).length

    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + (Aggregator.stats_bucket_size*1.9).to_i)) do
      Aggregator.aggregate_all([{:service_id     => 1001,
                                :application_id => 2001,
                                :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                :usage          => {'3001' => 1}}])
    end
    assert_equal 1, Resque.queue(:main).length + Resque.queue(:stats).length

    ## antoher time bucket has elapsed

    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + (Aggregator.stats_bucket_size*2).to_i)) do
      Aggregator.aggregate_all([{:service_id     => 1001,
                                :application_id => 2001,
                                :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                :usage          => {'3001' => 1}}])
    end
    assert_equal 2, Resque.queue(:main).length + Resque.queue(:stats).length

  end

  test 'Distribute stats job per service' do
    assert_equal 0, Resque.queue(:main).length + Resque.queue(:stats).length

    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45)) do
      Aggregator.aggregate_all([{:service_id     => 1001,
                                :application_id => 2001,
                                :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                :usage          => {'3001' => 1}}])
    end
    assert_equal 0, Resque.queue(:main).length + Resque.queue(:stats).length
    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45 + (Aggregator.stats_bucket_size*1.9).to_i)) do
      Aggregator.aggregate_all(
        [
          { service_id: 1001,
            application_id: 2001,
            timestamp: Time.utc(2010, 5, 7, 13, 23, 33),
            usage: {'3001' => 1}
          },
          {
            service_id:     1002,
            application_id: 2002,
            timestamp: Time.utc(2010, 5, 7, 13, 23, 33),
            usage: {'3002' => 1}
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
    timestamp = Time.utc(2010, 5, 7, 13, 23, 33)

    cont.times do
      Aggregator.aggregate_all([{:service_id     => 1001,
                                :application_id => 2001,
                                :timestamp      => timestamp,
                                :usage          => {'3001' => 1}}])
    end

    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length

    time_with_mongo = Time.now - t

    mongo_conditions = { s: "1001", m: "3001" }
    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :eternity))
    assert_equal cont, @storage_mongo.get(:eternity, timestamp, mongo_conditions)

    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :month,  '20100501'))
    assert_equal cont, @storage_mongo.get(:month, timestamp, mongo_conditions)

    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :day,    '20100507'))
    assert_equal cont, @storage_mongo.get(:day, timestamp, mongo_conditions)

    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :hour,   '2010050713'))
    assert_equal cont, @storage_mongo.get(:hour, timestamp, mongo_conditions)

    mongo_conditions = { s: "1001", a: "2001", m: "3001" }
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :eternity))
    assert_equal cont, @storage_mongo.get(:eternity, timestamp, mongo_conditions)

    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :year,   '20100101'))
    assert_equal cont, @storage_mongo.get(:year, timestamp, mongo_conditions)

    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :month,  '20100501'))
    assert_equal cont, @storage_mongo.get(:month, timestamp, mongo_conditions)

    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :month,  '20100501'))
    assert_equal cont, @storage_mongo.get(:day, timestamp, mongo_conditions)

    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal cont, @storage_mongo.get(:hour, timestamp, mongo_conditions)

    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :minute, '201005071323'))
    assert_equal cont, @storage_mongo.get(:minute, timestamp, mongo_conditions)

    @storage = Storage.instance(true)
    @storage.flushdb
    Memoizer.reset!
    seed_data()

    @storage_mongo = StorageMongo.instance(true)
    @storage_mongo.clear_collections

    mongo_conditions = { service: 1001, metric: 3001 }
    assert_equal nil, @storage_mongo.get(:eternity, timestamp, mongo_conditions)

    t = Time.now

    cont.times do
      Aggregator.aggregate_all([{:service_id     => 1001,
                                :application_id => 2001,
                                :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                :usage          => {'3001' => 1}}])
    end


    Aggregator::StatsTasks.schedule_one_stats_job()
    Resque.run!

    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length

    time_without_mongo = Time.now - t

    mongo_conditions = { service: "1001", metric: "3001" }
    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :eternity))
    assert_equal nil, @storage_mongo.get(:eternity, timestamp, mongo_conditions)

    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :month,  '20100501'))
    assert_equal nil, @storage_mongo.get(:month, timestamp, mongo_conditions)

    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :day,    '20100507'))
    assert_equal nil, @storage_mongo.get(:day, timestamp, mongo_conditions)

    assert_equal cont.to_s, @storage.get(service_key(1001, 3001, :hour,   '2010050713'))
    assert_equal nil, @storage_mongo.get(:hour, timestamp, mongo_conditions)

    mongo_conditions = { service: "1001", application: "2001", metric: "3001" }
    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :eternity))
    assert_equal nil, @storage_mongo.get(:eternity, timestamp, mongo_conditions)

    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :year,   '20100101'))
    assert_equal nil, @storage_mongo.get(:year, timestamp, mongo_conditions)

    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :month,  '20100501'))
    assert_equal nil, @storage_mongo.get(:month, timestamp, mongo_conditions)

    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :day,    '20100507'))
    assert_equal nil, @storage_mongo.get(:day, timestamp, mongo_conditions)

    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal nil, @storage_mongo.get(:hour, timestamp, mongo_conditions)

    assert_equal cont.to_s, @storage.get(application_key(1001, 2001, 3001, :minute, '201005071323'))
    assert_equal nil, @storage_mongo.get(:minute, timestamp, mongo_conditions)

    good_enough = time_with_mongo < time_without_mongo * 1.5

    if (!good_enough)
      puts "\nwith    mongodb: #{time_with_mongo}s"
      puts "without mongodb: #{time_without_mongo}s\n"
    end

    assert_equal true, good_enough
  end

  test 'aggregate_all increments_all_stats_counters' do
    timestamp = Time.utc(2010, 5, 7, 13, 23, 33)
    Aggregator.aggregate_all([{:service_id     => 1001,
                               :application_id => 2001,
                               :timestamp      => timestamp,
                               :usage          => {'3001' => 1}}])

    assert_equal 0 , Resque.queue(:main).length  + Resque.queue(:stats).length
    Aggregator::StatsTasks.schedule_one_stats_job
    assert_equal 1 , Resque.queue(:main).length + Resque.queue(:stats).length
    Resque.run!
    assert_equal 0 , Resque.queue(:main).length + Resque.queue(:stats).length

    mongo_conditions = { s: "1001", m: "3001" }

    assert_equal '1', @storage.get(service_key(1001, 3001, :eternity))
    assert_equal 1, @storage_mongo.get(:eternity, timestamp, mongo_conditions)

    assert_equal '1', @storage.get(service_key(1001, 3001, :month,  '20100501'))
    assert_equal 1, @storage_mongo.get(:month, timestamp, mongo_conditions)

    assert_equal '1', @storage.get(service_key(1001, 3001, :day,    '20100507'))
    assert_equal 1, @storage_mongo.get(:day, timestamp, mongo_conditions)

    assert_equal '1', @storage.get(service_key(1001, 3001, :hour,   '2010050713'))
    assert_equal 1, @storage_mongo.get(:hour, timestamp, mongo_conditions)


    mongo_conditions = { s: "1001", a: "2001", m: "3001" }

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :eternity))
    assert_equal 1, @storage_mongo.get(:eternity, timestamp, mongo_conditions)

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :year,   '20100101'))
    assert_equal 1, @storage_mongo.get(:year, timestamp, mongo_conditions)

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :month,  '20100501'))
    assert_equal 1, @storage_mongo.get(:month, timestamp, mongo_conditions)

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :day,    '20100507'))
    assert_equal 1, @storage_mongo.get(:day, timestamp, mongo_conditions)

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 1, @storage_mongo.get(:hour, timestamp, mongo_conditions)

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :minute, '201005071323'))
    assert_equal 1, @storage_mongo.get(:minute, timestamp, mongo_conditions)
  end

  test 'aggregate takes into account setting the counter value ok' do
    timestamp = Time.utc(2010, 5, 7, 13, 23, 33)
    mongo_conditions = { s: "1001", a: "2001", m: "3001" }

    v = []
    10.times do
      v <<   { :service_id     => 1001,
              :application_id => 2001,
              :timestamp      => timestamp,
              :usage          => {'3001' => 1}}

    end

    Aggregator.aggregate_all(v)
    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    assert_equal 10, @storage_mongo.get(:hour, timestamp, mongo_conditions)

    v = []
    v  <<   { :service_id     => 1001,
             :application_id => 2001,
             :timestamp      => timestamp,
             :usage          => {'3001' => '#665'}}

    Aggregator.aggregate_all(v)

    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    assert_equal 665, @storage_mongo.get(:hour, timestamp, mongo_conditions)

    v = []
    v <<   { :service_id     => 1001,
             :application_id => 2001,
             :timestamp      => timestamp,
             :usage          => {'3001' => '1'}}

    Aggregator.aggregate_all(v)

    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    assert_equal 666, @storage_mongo.get(:hour, timestamp, mongo_conditions)
  end

  test 'direct test of get_old_buckets_to_process' do
    ## this should go as unit test of StatsBatcher
    @storage.zadd(Aggregator::StatsKeys.changed_keys_key,"20121010102100","20121010102100")
    assert_equal [], Aggregator::StatsInfo.get_old_buckets_to_process("20121010102100")

    assert_equal ["20121010102100"], Aggregator::StatsInfo.get_old_buckets_to_process("20121010102120")

    assert_equal [], Aggregator::StatsInfo.get_old_buckets_to_process("20121010102120")


    @storage.del(Aggregator::StatsKeys.changed_keys_key)

    100.times do |i|
      @storage.zadd(Aggregator::StatsKeys.changed_keys_key,i,i.to_s)
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
    assert_equal ["2", "3", "4", "5", "6", "7", "8", "9", "10"], v

    v = Aggregator::StatsInfo.get_old_buckets_to_process
    assert_equal 89, v.size

    v = Aggregator::StatsInfo.get_old_buckets_to_process
    assert_equal [], v
  end

  test 'concurrency test on get_old_buckets_to_process' do

    ## this should go as unit test of StatsBatcher
    100.times do |i|
      @storage.zadd(Aggregator::StatsKeys.changed_keys_key,i,i.to_s)
    end

    10.times do |i|
      threads = []
      cont = 0

      20.times do |j|
        threads << Thread.new {
          r = Redis.new(host: '127.0.0.1', port: 22121)
          v = Aggregator::StatsInfo.get_old_buckets_to_process(((i+1)*10).to_s,r)

          assert (v.size==0 || v.size==10)

          cont=cont+1 if v.size==10


        }
      end

      threads.each do |t|
        t.join
      end

      assert_equal 1, cont

    end
  end

  test 'bucket keys are properly assigned' do
    timestamp  = Time.now.utc - 1000
    service_id = 1001

    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length

    5.times do |cont|
      bucket_key = timestamp.beginning_of_bucket(Aggregator.stats_bucket_size).to_not_compact_s

      Timecop.freeze(timestamp) do
        Aggregator.aggregate_all([{:service_id    => service_id,
                                  :application_id => 2001,
                                  :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                  :usage          => {'3001' => 1}}])

      end

      assert_equal cont+1, Aggregator::StatsInfo.pending_buckets.size

      assert Aggregator::StatsInfo.pending_buckets.member?("#{service_id}:#{bucket_key}")
      assert_equal cont, Resque.queue(:main).length + Resque.queue(:stats).length

      timestamp = timestamp + Aggregator.stats_bucket_size
    end

    assert_equal 5, Aggregator::StatsInfo.pending_buckets.size
    assert_equal 0, Aggregator::StatsInfo.failed_buckets.size

    sorted_set = Aggregator::StatsInfo.pending_buckets.sort

    4.times do |i|
      buckets = Aggregator::StatsInfo.get_old_buckets_to_process(sorted_set[i+1])
      assert_equal 1, buckets.size
      assert_equal sorted_set[i], buckets.first
    end

    assert_equal 1, Aggregator::StatsInfo.pending_buckets.size
    buckets = Aggregator::StatsInfo.get_old_buckets_to_process
    assert_equal 1, buckets.size
    assert_equal sorted_set[4], buckets.first
  end

  test 'failed cql batches get stored into redis and processed properly afterwards' do
    metrics_timestamp = Time.utc(2010, 5, 7, 13, 23, 33)

    ## first one ok,
    Aggregator.aggregate_all([{:service_id     => 1001,
                               :application_id => 2001,
                               :timestamp      => metrics_timestamp,
                               :usage          => {'3001' => 1}}])

    assert_equal 1, Aggregator::StatsInfo.pending_buckets.size
    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!
    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Aggregator::StatsInfo.failed_buckets.size

    assert_equal '1', @storage.get(service_key(1001, 3001, :eternity))
    mongo_conditions = { s: "1001", m: "3001" }
    assert_equal 1, @storage_mongo.get(:eternity, metrics_timestamp, mongo_conditions)

    ## on the second on we stub the storage_mongo to simulate a network error or mongo down

    @storage_mongo.stubs(:execute_batch).raises(Exception.new('bang!'))
    @storage_mongo.stubs(:get).raises(Exception.new('bang!'))

    timestamp = Time.now.utc - 1000

    5.times do
      Timecop.freeze(timestamp) do
        Aggregator.aggregate_all([{:service_id     => 1001,
                                  :application_id => 2001,
                                  :timestamp      => metrics_timestamp,
                                  :usage          => {'3001' => 1}}])

      end

      timestamp = timestamp + Aggregator.stats_bucket_size
    end

    ## failed_buckets is 0 because nothing has been tried and hence failed yet
    assert_equal 0, Aggregator::StatsInfo.failed_buckets.size
    assert_equal 0, Aggregator::StatsInfo.failed_buckets_at_least_once.size
    assert_equal 5, Aggregator::StatsInfo.pending_buckets.size

    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!
    assert_equal 0, Resque.queue(:main).length

    ## buckets went to the failed state
    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
    assert_equal 5, Aggregator::StatsInfo.failed_buckets.size
    assert_equal 5, Aggregator::StatsInfo.failed_buckets_at_least_once.size

    ## remove the stubbing
    @storage_mongo = StorageMongo.instance(true)

    assert_equal '6', @storage.get(service_key(1001, 3001, :eternity))
    mongo_conditions = { s: "1001", m: "3001" }
    assert_equal 1, @storage_mongo.get(:eternity, timestamp, mongo_conditions)

    ## now let's process the failed, one by one...

    v = Aggregator::StatsInfo.failed_buckets
    Aggregator.save_to_mongo(v.first)

    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
    assert_equal 4, Aggregator::StatsInfo.failed_buckets.size
    assert_equal 5, Aggregator::StatsInfo.failed_buckets_at_least_once.size


    assert_equal '6', @storage.get(service_key(1001, 3001, :eternity))
    assert_equal 6, @storage_mongo.get(:eternity, timestamp, mongo_conditions)

    ## or altogether

    v = Aggregator::StatsInfo.failed_buckets
    v.each do |bucket|
      Aggregator.save_to_mongo(bucket)
    end

    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
    assert_equal 0, Aggregator::StatsInfo.failed_buckets.size
    assert_equal 5, Aggregator::StatsInfo.failed_buckets_at_least_once.size


    assert_equal '6', @storage.get(service_key(1001, 3001, :eternity))
    assert_equal 6, @storage_mongo.get(:eternity, timestamp, mongo_conditions)
  end

  test 'aggregate takes into account setting the counter value in the case of failed batches' do
    @storage_mongo.stubs(:execute_batch).raises(Exception.new('bang!'))
    @storage_mongo.stubs(:get).raises(Exception.new('bang!'))

    timestamp = Time.utc(2010, 5, 7, 13, 23, 33)
    v = []
    10.times do
      v <<   { :service_id     => 1001,
              :application_id => 2001,
              :timestamp      => timestamp,
              :usage          => {'3001' => 1}}

    end

    Aggregator.aggregate_all(v)
    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    v = []
    v <<   { :service_id     => 1001,
             :application_id => 2001,
             :timestamp      => timestamp,
             :usage          => {'3001' => '#665'}}

    Aggregator.aggregate_all(v)
    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    v = []
    v <<   { :service_id     => 1001,
             :application_id => 2001,
             :timestamp      => timestamp,
             :usage          => {'3001' => '1'}}



    Aggregator.aggregate_all(v)
    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    ## it failed for mongodb

    @storage_mongo = StorageMongo.instance(true)

    assert_equal '666', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    mongo_conditions = { s: "1001", a: "2001", m: "3001" }
    assert_equal nil, @storage_mongo.get(:hour, timestamp, mongo_conditions)

    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
    assert_equal 1, Aggregator::StatsInfo.failed_buckets.size
    assert_equal 1, Aggregator::StatsInfo.failed_buckets_at_least_once.size

    v = Aggregator::StatsInfo.failed_buckets
    Aggregator.save_to_mongo(v.first)

    assert_equal '666', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal 666, @storage_mongo.get(:hour, timestamp, mongo_conditions)
  end

  test 'when mongodb is deactivated buckets are filled but nothing gets saved' do
    StorageStats.deactivate!

    v = []
    10.times do
      v <<   { :service_id     => 1001,
        :application_id => 2001,
        :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
        :usage          => {'3001' => 1}}

    end

    Aggregator.aggregate_all(v)

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

  test 'when mongodb is disabled nothing gets logged' do
    StorageStats.disable!
    ## the flag to know if mongo is enabled is memoized
    Memoizer.reset!

    v = []
    10.times do
      v <<   { :service_id     => 1001,
              :application_id => 2001,
              :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
              :usage          => {'3001' => 1}}

    end

    Aggregator.aggregate_all(v)

    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size

    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
  end

  test 'when mongo is disabled mongo does not have to be up and running, but stats get lost during the disabling period' do
    timestamp = Time.utc(2010, 5, 7, 13, 23, 33)
    v = []
    Timecop.freeze(Time.utc(2010, 5, 7, 13, 23, 33)) do
      10.times do
        v <<   { :service_id     => 1001,
                :application_id => 2001,
                :timestamp      => timestamp,
                :usage          => {'3001' => 1}}
      end
    end

    bkp_configuration = configuration.clone()

    configuration.mongo.servers = ["localhost:9090"]
    configuration.mongo.db = StorageMongo::DEFAULT_DATABASE

    # we set to nil the connection to mongo
    StorageMongo.reset_to_nil!

    ## now we disable it mongo
    StorageStats.disable!
    ## the flag to know if mongo is enabled is memoized
    Memoizer.reset!

    v.each do |item|
      Aggregator.aggregate_all([item])
    end

    Aggregator::StatsInfo.pending_buckets.size.times do
      Aggregator::StatsTasks.schedule_one_stats_job
    end
    Resque.run!

    ## because mongo is disabled nothing blows and nothing get logged, it's
    ## like the mongo code never existed
    assert_equal 0, Resque.queue(:main).length
    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size

    assert_equal '10', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    mongo_conditions = { service: "1001", application: "2001", metric: "3001" }
    assert_equal nil, @storage_mongo.get(:hour, timestamp, mongo_conditions)

    ## now, enabled it mongo and do the same

    configuration.mongo.servers = StorageMongo::DEFAULT_SERVER
    configuration.mongo.db = StorageMongo::DEFAULT_DATABASE
    StorageMongo.reset_to_nil!

    StorageStats.enable!
    ## the flag to know if mongo is enabled is memoized
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
    mongo_conditions = { s: "1001", a: "2001", m: "3001" }
    assert_equal 20, @storage_mongo.get(:hour, timestamp, mongo_conditions)
  end

  test 'when mongodb is deactivated mongo does not have to be up and running, but stats do NOT get lost during the deactivation period' do
    timestamp = Time.utc(2010, 5, 7, 13, 23, 33)
    v = []
    Timecop.freeze(timestamp) do
      10.times do
        v <<   { :service_id     => 1001,
                :application_id => 2001,
                :timestamp      => timestamp,
                :usage          => {'3001' => 1}}
      end
    end

    bkp_configuration = configuration.clone()

    configuration.mongo.servers = ["localhost:9090"]
    configuration.mongo.db = StorageMongo::DEFAULT_DATABASE

    ## we set to nil the connection to mongo
    StorageMongo.reset_to_nil!

    ## now we disable it mongo
    StorageStats.deactivate!

    v.each do |item|
      Aggregator.aggregate_all([item])
    end

    assert_equal 1, Aggregator::StatsInfo.pending_buckets.size

    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!

    ## because mongo is deactivated nothing blows but it gets logged waiting for mongo
    ## to be in place again
    assert_equal 0, Resque.queue(:main).length
    assert_equal 1, Aggregator::StatsInfo.pending_buckets.size

    assert_equal '10', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    mongo_conditions = { service: 1001, application: 2001, metric: 3001 }
    assert_equal nil, @storage_mongo.get(:hour, timestamp, mongo_conditions)

    ## now, enabled it mongo and do the same

    configuration.mongo.servers = StorageMongo::DEFAULT_SERVER
    configuration.mongo.db = StorageMongo::DEFAULT_DATABASE
    StorageMongo.reset_to_nil!

    StorageStats.activate!

    assert_equal 1, Aggregator::StatsInfo.pending_buckets.size

    sleep(Aggregator.stats_bucket_size)

    v.each do |item|
      Aggregator.aggregate_all([item])
    end

    assert_equal 2, Aggregator::StatsInfo.pending_buckets.size

    Aggregator::StatsTasks.schedule_one_stats_job()
    Resque.run!

    assert_equal 0, Aggregator::StatsInfo.pending_buckets.size
    assert_equal 0, Resque.queue(:main).length

    assert_equal '20', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    mongo_conditions = { s: "1001", a: "2001", m: "3001" }
    assert_equal 20, @storage_mongo.get(:hour, timestamp, mongo_conditions)
  end


  test 'applications with end user plans (user_id) get recorded properly' do
    default_user_plan_id = next_id
    default_user_plan_name = "user plan mobile"
    timestamp = Time.utc(2010, 5, 7, 13, 23, 33)

    service = Service.save!(:provider_key => @provider_key, :id => next_id)
    #
    # TODO: Temporary stubs until we decouple Backend::User from Core::User
    Core::Service.stubs(:load_by_id).returns(service)
    service.stubs :user_add

    service.user_registration_required = false
    service.default_user_plan_name = default_user_plan_name
    service.default_user_plan_id = default_user_plan_id
    service.save!

    application = Application.save(:service_id => service.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id,
                                    :plan_name  => @plan_name,
                                    :user_required => true)

    Aggregator.aggregate_all([{:service_id     => service.id,
                               :application_id => application.id,
                               :timestamp      => timestamp,
                               :usage          => {@metric_hits.id => 5},
                               :user_id        => "user_id_xyz"}])

    Aggregator::StatsInfo.pending_buckets.size.times do |cont|
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


    mongo_conditions = { s: service.id, a: application.id, m: @metric_hits.id.to_s }
    assert_equal 5, @storage_mongo.get(:hour, timestamp, mongo_conditions)
    assert_equal 5, @storage_mongo.get(:month, timestamp, mongo_conditions)
    assert_equal 5, @storage_mongo.get(:eternity, timestamp, mongo_conditions)

    mongo_conditions = { s: service.id, m: @metric_hits.id.to_s }
    assert_equal 5, @storage_mongo.get(:hour, timestamp, mongo_conditions)
    assert_equal 5, @storage_mongo.get(:month, timestamp, mongo_conditions)
    assert_equal 5, @storage_mongo.get(:eternity, timestamp, mongo_conditions)

    mongo_conditions = { s: service.id, e: "user_id_xyz", m: @metric_hits.id.to_s }

    assert_equal 5, @storage_mongo.get(:hour, timestamp, mongo_conditions)
    assert_equal 5, @storage_mongo.get(:month, timestamp, mongo_conditions)
    assert_equal 5, @storage_mongo.get(:eternity, timestamp, mongo_conditions)

    Aggregator.aggregate_all([{:service_id     => service.id,
                               :application_id => application.id,
                               :timestamp      => timestamp,
                               :usage          => {@metric_hits.id => 4},
                               :user_id        => "another_user_id_xyz"}])

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

    mongo_conditions = { s: service.id, a: application.id, m: @metric_hits.id.to_s }
    assert_equal 9, @storage_mongo.get(:hour, timestamp, mongo_conditions)
    assert_equal 9, @storage_mongo.get(:month, timestamp, mongo_conditions)
    assert_equal 9, @storage_mongo.get(:eternity, timestamp, mongo_conditions)

    mongo_conditions = { s: service.id, m: @metric_hits.id.to_s }
    assert_equal 9, @storage_mongo.get(:hour, timestamp, mongo_conditions)
    assert_equal 9, @storage_mongo.get(:month, timestamp, mongo_conditions)
    assert_equal 9, @storage_mongo.get(:eternity, timestamp, mongo_conditions)

    mongo_conditions = { s: service.id, e: "another_user_id_xyz", m: @metric_hits.id.to_s }
    assert_equal 4, @storage_mongo.get(:hour, timestamp, mongo_conditions)
    assert_equal 4, @storage_mongo.get(:month, timestamp, mongo_conditions)
    assert_equal 4, @storage_mongo.get(:eternity, timestamp, mongo_conditions)
  end

  test 'delete all buckets and keys' do
    @storage_mongo.stubs(:execute_batch).raises(Exception.new('bang!'))
    @storage_mongo.stubs(:get).raises(Exception.new('bang!'))

    timestamp = Time.now.utc - 1000

    5.times do

      Timecop.freeze(timestamp) do
        Aggregator.aggregate_all([{:service_id     => 1001,
                                  :application_id => 2001,
                                  :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                  :usage          => {'3001' => 1}}])

      end

      timestamp = timestamp + Aggregator.stats_bucket_size
    end

    ## failed_buckets is 0 because nothing has been tried and hence failed yet
    assert_equal 0, Aggregator::StatsInfo.failed_buckets.size
    assert_equal 5, Aggregator::StatsInfo.pending_buckets.size

    Aggregator::StatsTasks.schedule_one_stats_job
    Resque.run!
    assert_equal 0, Resque.queue(:main).length

    ## jobs did not do anything because mongo connection failed
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
    Aggregator.aggregate_all([{:service_id     => 1001,
                               :application_id => 2001,
                               :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                               :usage          => {'3001' => 1}}])

    assert_equal ['2001'], @storage.smembers("stats/{service:1001}/cinstances")
  end

  test 'aggregate_all does not update service set' do
    assert_no_change :of => lambda { @storage.smembers('stats/services') } do
      Aggregator.aggregate_all([{:service_id     => '1001',
                                 :application_id => '2001',
                                 :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                                 :usage          => {'3001' => 1}}])
    end
  end

  test 'aggregate_all sets expiration time for volatile keys' do
    Aggregator.aggregate_all([{:service_id     => '1001',
                               :application_id => '2001',
                               :timestamp      => Time.utc(2010, 5, 7, 13, 23, 33),
                               :usage          => {'3001' => 1}}])


    key = application_key('1001', '2001', '3001', :minute, 201005071323)
    ttl = @storage.ttl(key)

    assert_not_equal -1, ttl
    assert ttl >  0
    assert ttl <= 180
  end
end
