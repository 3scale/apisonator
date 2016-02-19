module ThreeScale
  module Backend
    # Worker for working off background jobs. This is very stripped down version of the
    # default resque worker with parts of code shamelessly stolen from it. The reason for
    # this stripping is that the resque one does fork before processing each job, and that
    # is too slow.

    class Worker
      include Resque::Helpers
      include Configurable

      # the order is relevant
      QUEUES = [:priority, :main, :stats]
      REDIS_TIMEOUT = 60

      def initialize(options)
        trap('TERM') { shutdown }
        trap('INT')  { shutdown }

        @one_off = options[:one_off]

        configure_airbrake_for_resque if Airbrake.configuration.api_key
      end

      def self.new(options = {})
        pid = Process.pid
        Logging.enable! on: self.singleton_class, with: [
            options.delete(:log_file) || configuration.workers_log_file || '/dev/null'
          ] do |logger|
            logger.formatter = proc { |severity, datetime, progname, msg|
              "#{severity} #{pid} #{datetime.getutc.strftime("[%d/%b/%Y %H:%M:%S %Z]")} #{msg}\n"
            }
        end

        super
      end

      # == Options
      #
      # - :one_off           - if true, will process one job, then quit
      #
      def self.work(options = {})
        Process.setproctitle("3scale_backend_worker #{ThreeScale::Backend::VERSION}")
        new(options).work
      end

      def work
        register_worker

        loop do
          break if @shutdown

          job = reserve
          perform(job) if job

          break if one_off?
        end

        unregister_worker
      end

      def shutdown
        @shutdown = true
      end

      def to_s
        @to_s ||= "#{hostname}:#{Process.pid}:#{QUEUES.join(',')}"
      end

      def one_off?
        @one_off
      end

      private

      def reserve
        @queues ||= QUEUES.map { |q| "queue:#{q}" }
        encoded_job = redis.blpop(*@queues, timeout: redis_timeout)

        return nil if encoded_job.nil? || encoded_job.empty?

        begin
          Resque::Job.new(encoded_job[0],
                          Yajl::Parser.parse(encoded_job[1], check_utf8: false))
        rescue Yajl::ParseError => e
          Airbrake.notify(e) # To know if we are storing bad data in Resque
          nil
        end
      end

      def perform(job)
        job.perform
      rescue Exception => e
        job.fail(e)
        failed!
      end

      def register_worker
        redis.sadd(:workers, self)
        started!
      end

      def unregister_worker
        redis.srem(:workers, self)
        stopped!
      end

      def redis_timeout
        REDIS_TIMEOUT
      end

      def hostname
        @hostname ||= `hostname`.chomp
      end

      def configure_airbrake_for_resque
        require 'resque/failure/multiple'
        require 'resque/failure/airbrake'
        require 'resque/failure/redis'

        Resque::Failure::Multiple.classes = [
          Resque::Failure::Redis,
          Resque::Failure::Airbrake,
        ]
        Resque::Failure.backend = Resque::Failure::Multiple
      end

      ## the next 4 are required for resque, leave them as is
      def started!; end

      def stopped!; end

      def processed!; end

      def failed!; end
      ## ----
    end
  end
end
