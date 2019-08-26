require '3scale/backend/configuration'
require '3scale/backend/logging/worker'
require '3scale/backend/logging/external'
require '3scale/backend/job_fetcher'

module ThreeScale
  module Backend
    # Worker for working off background jobs. This is very stripped down version of the
    # default resque worker with parts of code shamelessly stolen from it. The reason for
    # this stripping is that the resque one does fork before processing each job, and that
    # is too slow.

    class Worker
      include Resque::Helpers
      include Configurable

      def initialize(options)
        trap('TERM') { shutdown }
        trap('INT')  { shutdown }

        @one_off = options[:one_off]
      end

      def self.new(options = {})
        Logging::Worker.configure_logging(self, options[:log_file])
        Logging::External.setup_worker

        if configuration.worker_prometheus_metrics.enabled
          require '3scale/backend/worker_metrics'
          WorkerMetrics.start_metrics_server
        end

        super
      end

      # == Options
      #
      # - :one_off           - if true, will process one job, then quit
      #
      def self.work(options = {})
        Process.setproctitle("3scale_backend_worker #{Backend::VERSION}")
        new(options).work
      end

      def work
        job_fetcher = JobFetcher.new

        register_worker

        loop do
          break if @shutdown

          job = job_fetcher.fetch
          perform(job) if job

          break if one_off?
        end

        unregister_worker
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
        redis.sadd(:workers, self)
      end

      def unregister_worker
        redis.srem(:workers, self)
      end

      def hostname
        @hostname ||= (ENV['HOSTNAME'] || `hostname`.chomp)
      end
    end
  end
end
