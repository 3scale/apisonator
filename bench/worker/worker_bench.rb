require "3scale/backend/job_fetcher"

class WorkerBenchmark
  include Benchmark
  include TestHelpers::Fixtures

  def initialize
    super
    @async = ThreeScale::Backend.configuration.redis.async
  end

  def async?
    @async
  end

  def create_reports(num)
    warn "generating #{num} transactions.."
    num.times { default_report }
  end

  def new_worker(fetcher = nil)
    Worker.new(async: async?, job_fetcher: fetcher)
  end

  def clear_queue
    fetcher = JobFetcher.new(fetch_timeout: 1)
    worker = new_worker(fetcher)
    queues = fetcher.instance_variable_get(:@queues)
    redis = async? ? fetcher.instance_variable_get(:@redis) : dup_resque_redis

    warn "Queue has #{queue_len(redis, queues)} jobs.."

    workaholic = async? ? Async { worker.work } : Thread.new { worker.work }

    # yes, we are doing some fast queries but it is constant and in a real world scenario, there will be other queries
    sleep 0.1 while queue_len(redis, queues) > 0

    warn "Shutting down worker.."
    worker.shutdown

    async? ? workaholic.wait : workaholic.join
  end

  def queue_len(client, queues)
    queues.map { client.llen _1 }.sum
  end

  def dup_resque_redis
    client_orig = Resque.instance_variable_get :@data_store
    Resque.instance_variable_set(:@data_store, nil)
    ThreeScale::Backend.set_resque_redis
    client_new = Resque.instance_variable_get :@data_store
    Resque.instance_variable_set(:@data_store, client_orig)
    client_new
  end

  def run
    new_worker # initialize worker to configure logging, good to improve that one day
    orig_log_level = Worker.logger.level
    Worker.logger.warn!

    Memoizer.reset!
    storage(true).flushdb
    seed_data

    create_reports(10_000)
    Benchmark.measure('10k reports') do |x|
      clear_queue
    end

    res = []
    create_reports(100_000)
    res << Benchmark.measure('100k reports') do |x|
      clear_queue
    end

    create_reports(1_000_000)
    res << Benchmark.measure('1m reports') do |x|
      clear_queue
    end

    warn "=" * 70
    warn Benchmark::CAPTION
    res.each { warn _1.format(Benchmark::Tms::FORMAT).chop + " (#{_1.label})" }
    warn "=" * 70
  ensure
    Worker.logger.level = orig_log_level if orig_log_level
  end
end

WorkerBenchmark.new.run
