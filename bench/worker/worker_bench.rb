require "3scale/backend/job_fetcher"

class WorkerBenchmark
  include Benchmark
  include TestHelpers::Fixtures

  def initialize
    super
    @async = ThreeScale::Backend.configuration.redis.async
    @nreports = ENV.fetch('NUM_REPORTS', "100000")
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
    n_reports = @nreports.split(',').map(&:strip).map(&:to_i)

    # Warming up...
    run_benchark(10000)

    reports = n_reports.map { run_benchark(_1) }

    print_reports reports
  end

  def print_reports(reports)
    warn "=" * 70
    warn Benchmark::CAPTION

    reports.each do |res, rss|
      warn res.format(Benchmark::Tms::FORMAT).chop + " #{rss}KB" + " (#{res.label})"
    end

    warn "=" * 70
  end

  def run_benchark(n_reports)
    new_worker # initialize worker to configure logging, good to improve that one day
    orig_log_level = Worker.logger.level
    Worker.logger.warn!

    Memoizer.reset!
    storage(true).flushdb
    seed_data

    create_reports(n_reports)
    res = Benchmark.measure( "#{n_reports} reports") do |x|
      clear_queue
    end

    rss = `ps -o rss #{Process.pid}`.lines.last.to_i

    [res, rss]
  ensure
    Worker.logger.level = orig_log_level if orig_log_level
  end
end

WorkerBenchmark.new.run
