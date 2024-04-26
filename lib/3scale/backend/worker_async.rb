require 'async'
require 'async/semaphore'
require 'async/barrier'
require '3scale/backend/job_fetcher'

module ThreeScale
  module Backend
    class WorkerAsync
      include Backend::Worker
      include Configurable

      DEFAULT_MAX_PENDING_JOBS = 100
      private_constant :DEFAULT_MAX_PENDING_JOBS

      def initialize(options = {})
        trap('TERM') { shutdown }
        trap('INT')  { shutdown }

        @one_off = options[:one_off]
        @jobs = SizedQueue.new(max_pending_jobs)

        @job_fetcher = options[:job_fetcher] || JobFetcher.new

        @max_concurrent_jobs = configuration.async_worker.max_concurrent_jobs || Worker::DEFAULT_MAX_CONCURRENT_JOBS
      end

      def work
        return Sync { process_one } if one_off?

        Sync do
          register_worker
        end

        Sync do
          start_to_fetch_jobs
          process_all
        end

        # Ensure that we do not leave any jobs in memory
        Sync { clear_queue }

        Sync { unregister_worker }
      end

      def shutdown
        Worker.logger.info "Shutting down fetcher.."
        @job_fetcher.shutdown
      end

      private

      def process_one
        job = @job_fetcher.fetch
        perform(job) if job
      end

      def process_all
        barrier = Async::Barrier.new
        semaphore = Async::Semaphore.new(@max_concurrent_jobs, parent: barrier)

        Worker.logger.info "Start processing all.."

        loop do
          # unblocks when there are new jobs or when .close() is called
          job = @jobs.pop

          # If job is nil, it means that the queue is closed. No more jobs are
          # going to be pushed, so quit.
          unless job
            break if @jobs.closed? && @jobs.empty?

            Worker.logger.error("Worker received a nil job from queue.")

            next
          end

          semaphore.async { perform(job) }

          # Clean-up tasks inside barrier regularly, otherwise they accumulate throughout the worker lifetime
          # and never GCed, eventually exhausting the whole available memory. Moreover the array keeping
          # track of tasks in the barrier grows indefinitely too occupying memory and reducing performance.
          if barrier.size > max_pending_jobs
            barrier.wait
          end
        end
      ensure
        barrier.wait
      end

      def clear_queue
        barrier = Async::Barrier.new
        semaphore = Async::Semaphore.new(@max_concurrent_jobs, parent: barrier)

        while (job = @jobs.pop)
          semaphore.async { perform(job) }
        end
      ensure
        barrier.wait
      end

      def start_to_fetch_jobs
        Async(transient: true) { @job_fetcher.start(@jobs) }
      end

      private

      def max_pending_jobs
        @max_pending_jobs ||= configuration.async_worker.max_pending_jobs || DEFAULT_MAX_PENDING_JOBS
      end
    end
  end
end
