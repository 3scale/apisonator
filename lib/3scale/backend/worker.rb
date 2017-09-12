module ThreeScale
  module Backend
    # Worker for working off background jobs. This is very stripped down version of the
    # default resque worker with parts of code shamelessly stolen from it. The reason for
    # this stripping is that the resque one does fork before processing each job, and that
    # is too slow.

    class Worker
      module SaaS
        private

        def configure_airbrake?
          Airbrake.configuration.api_key
        end
      end
      private_constant :SaaS

      module OnPrem
        private

        def configure_airbrake?
          false
        end
      end
      private_constant :OnPrem

      include(ThreeScale::Backend.configuration.saas ? SaaS : OnPrem)

      include Resque::Helpers
      include Configurable
      require '3scale/backend/logger/worker'

      # the order is relevant
      QUEUES = [:priority, :main, :stats]
      REDIS_TIMEOUT = 60

      def initialize(options)
        trap('TERM') { shutdown }
        trap('INT')  { shutdown }

        @one_off = options[:one_off]

        configure_airbrake_for_resque
      end

      def self.new(options = {})
        Logger::Worker.configure_logging(self, options[:log_file])
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
          # Resque::Job.new accepts a queue name as a param. It is very
          # important to set here the same name as the one we set when calling
          # Resque.enqueue. Resque.enqueue uses the @queue ivar in
          # BackgroundJob classes as the name of the queue, and then, it stores
          # the job in a queue called resque:queue:_@queue_. 'resque:' is the
          # namespace and 'queue:' is added automatically. That's why we need
          # to call blpop on 'queue:#{q}' above. However, when creating the job
          # we cannot set 'queue:#{q}' as the name. Otherwise, if it fails and
          # it is re-queued, it will end up in resque:queue:queue:_@queue_
          # instead of resque:queue:_@queue_.
          encoded_job[0].sub!('queue:', '')
          Resque::Job.new(encoded_job[0],
                          Yajl::Parser.parse(encoded_job[1], check_utf8: false))
        rescue Exception => e
          # I think that the only exception that can be raised here is
          # Yajl::ParseError. However, this is a critical part of the code so
          # we will capture all of them just to be safe.
          Worker.logger.notify(e)
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
        @hostname ||= (ENV['HOSTNAME'] || `hostname`.chomp)
      end

      def configure_airbrake_for_resque
        if configure_airbrake?
          require 'resque/failure/multiple'
          require 'resque/failure/airbrake'
          require 'resque/failure/redis'

          Resque::Failure::Multiple.classes = [
            Resque::Failure::Redis,
            Resque::Failure::Airbrake,
          ]
          Resque::Failure.backend = Resque::Failure::Multiple
        end
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
