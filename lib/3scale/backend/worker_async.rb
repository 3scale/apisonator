require 'async'
require 'async/barrier'
require 'async/semaphore'
require 'redis-namespace'
require '3scale/backend/job_fetcher'

module ThreeScale
  module Backend
    class WorkerAsync
      include Backend::Worker
      include Configurable

      DEFAULT_MAX_CONCURRENT_JOBS = 20
      private_constant :DEFAULT_MAX_CONCURRENT_JOBS

      RESQUE_REDIS_NAMESPACE = :resque
      private_constant :RESQUE_REDIS_NAMESPACE

      def initialize(options = {})
        trap('TERM') { shutdown }
        trap('INT')  { shutdown }

        @one_off = options[:one_off]
        @jobs = Queue.new # Thread-safe queue

        @job_fetcher = options[:job_fetcher] || JobFetcher.new(redis_client: redis_client)

        max_concurrent_jobs = configuration.async_worker.max_concurrent_jobs ||
            DEFAULT_MAX_CONCURRENT_JOBS

        @barrier = Async::Barrier.new
        @semaphore = Async::Semaphore.new(max_concurrent_jobs, parent: @barrier)
      end

      def work
        if one_off?
          Async { process_one }
          return
        end

        Async { register_worker }

        fetch_jobs_thread = start_thread_to_fetch_jobs

        loop do
          # unblocks when there are new jobs or when .close() is called
          job = @jobs.pop

          # If job is nil, it means that the queue is closed. No more jobs are
          # going to be pushed, so shutdown.
          shutdown unless job

          break if @shutdown

          @semaphore.async { perform(job) }
        end

        fetch_jobs_thread.join

        # Ensure that we do not leave any jobs in memory
        @semaphore.async { perform(@jobs.pop) } until @jobs.empty?
        @barrier.wait

        Async { unregister_worker }
      ensure
        @barrier.stop
      end

      def shutdown
        @job_fetcher.shutdown
        @shutdown = true
      end

      private

      def process_one
        job = @job_fetcher.fetch
        perform(job) if job
      end

      def start_thread_to_fetch_jobs
        Thread.new do
          Async { @job_fetcher.start(@jobs) }
        end
      end

      # Returns a new Redis client with namespace "resque".
      # In the async worker, the job fetcher runs in a separate thread, and we
      # need to avoid sharing an already instantiated client like the one in
      # Resque::Helpers initialized in lib/3scale/backend.rb (Resque.redis).
      # Failing to do so, will raise errors because of fibers shared across
      # threads.
      def redis_client
        Redis::Namespace.new(
          RESQUE_REDIS_NAMESPACE,
          redis: QueueStorage.connection(Backend.environment, Backend.configuration)
        )
      end
    end
  end
end
