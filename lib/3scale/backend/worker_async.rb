require 'async'
require 'async/semaphore'
require 'async/barrier'
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

        @max_concurrent_jobs = configuration.async_worker.max_concurrent_jobs ||
            DEFAULT_MAX_CONCURRENT_JOBS
      end

      def work
        return Sync { process_one } if one_off?

        Sync { register_worker }

        fetch_jobs_thread = start_thread_to_fetch_jobs

        Sync { process_all }

        fetch_jobs_thread.join

        # Ensure that we do not leave any jobs in memory
        Sync { clear_queue }

        Sync { unregister_worker }
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

      def process_all
        barrier = Async::Barrier.new
        semaphore = Async::Semaphore.new(@max_concurrent_jobs, parent: barrier)

        loop do
          # unblocks when there are new jobs or when .close() is called
          job = @jobs.pop

          # If job is nil, it means that the queue is closed. No more jobs are
          # going to be pushed, so shutdown.
          shutdown unless job

          break if @shutdown

          semaphore.async { perform(job) }
          barrier.wait if barrier.size > semaphore.limit
        end
      ensure
        barrier.stop
      end

      def clear_queue
        barrier = Async::Barrier.new
        semaphore = Async::Semaphore.new(@max_concurrent_jobs, parent: barrier)

        while (job = @jobs.pop)
          semaphore.async { perform(job) }
        end
      ensure
        barrier.wait
        barrier.stop
      end

      def start_thread_to_fetch_jobs
        Thread.new do
          Sync { @job_fetcher.start(@jobs) }
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
