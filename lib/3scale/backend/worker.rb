require '3scale/backend/configuration'
require '3scale/backend/logging/worker'
require '3scale/backend/logging/external'

module ThreeScale
  module Backend
    # Worker for working off background jobs. This is very stripped down version of the
    # default resque worker with parts of code shamelessly stolen from it. The reason for
    # this stripping is that the resque one does fork before processing each job, and that
    # is too slow.

    # This is a module that's meant to be included from the different workers.
    # Now we have WorkerSync and WorkerAsync. Those classes need to implement
    # #work, which is responsible for fetching jobs from the queue and running
    # them by calling perform(job).
    module Worker
      include Resque::Helpers
      include Configurable

      DEFAULT_MAX_CONCURRENT_JOBS = 20

      def self.new(options = {})
        Logging::Worker.configure_logging(self, options[:log_file])
        Logging::External.setup_worker

        if configuration.worker_prometheus_metrics.enabled
          require '3scale/backend/worker_metrics'
          WorkerMetrics.start_metrics_server
        end

        if options[:async]
          # Conditional require is done to require async-* libs only when
          # needed and avoid possible side-effects.
          require '3scale/backend/worker_async'
          WorkerAsync.new(options)
        else
          require '3scale/backend/worker_sync'
          WorkerSync.new(options)
        end
      end

      # == Options
      #
      # - :one_off           - if true, will process one job, then quit
      #
      def self.work(options = {})
        Process.setproctitle("3scale_backend_worker #{Backend::VERSION}")
        options[:async] = configuration.redis.async
        new(options).work
      end

      def work
        raise 'Missing implementation of #work'
      end

      def shutdown
        @shutdown = true
      end

      def to_s
        @to_s ||= "#{hostname}:#{Process.pid}"
      end

      def one_off?
        @one_off
      end

      private

      def perform(job)
        job.perform
      rescue Exception => e
        job.fail(e)
      end

      def register_worker
        redis.sadd(:workers, self.to_s)
      end

      def unregister_worker
        redis.srem(:workers, self.to_s)
      end

      def hostname
        @hostname ||= (ENV['HOSTNAME'] || `hostname`.chomp)
      end
    end
  end
end
