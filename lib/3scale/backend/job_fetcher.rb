module ThreeScale
  module Backend
    class JobFetcher
      include Resque::Helpers
      include Configurable

      # the order is relevant
      QUEUES = [:priority, :main, :stats].freeze
      private_constant :QUEUES

      REDIS_TIMEOUT = 60
      private_constant :REDIS_TIMEOUT

      DEFAULT_MAX_PENDING_JOBS = 100
      private_constant :DEFAULT_MAX_PENDING_JOBS

      DEFAULT_WAIT_BEFORE_FETCHING_MORE_JOBS = 1.0/100
      private_constant :DEFAULT_WAIT_BEFORE_FETCHING_MORE_JOBS

      # The default redis_client is the one defined in Resque::Helpers
      def initialize(redis_client: redis, fetch_timeout: REDIS_TIMEOUT)
        @redis = redis_client
        @fetch_timeout = fetch_timeout
        @queues ||= QUEUES.map { |q| "queue:#{q}" }

        @max_pending_jobs = configuration.async_worker.max_pending_jobs ||
            DEFAULT_MAX_PENDING_JOBS

        @wait_before_fetching_more = configuration.async_worker.seconds_before_fetching_more ||
            DEFAULT_WAIT_BEFORE_FETCHING_MORE_JOBS
      end

      def fetch
        encoded_job = @redis.blpop(*@queues, timeout: @fetch_timeout)

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

      # Note: this method calls #close on job_queue after receiving #shutdown.
      # That signals to the caller that there won't be any more jobs.
      def start(job_queue)
        loop do
          break if @shutdown

          if job_queue.size >= @max_pending_jobs
            sleep @wait_before_fetching_more
          else
            job = fetch
            job_queue << job if job
          end
        end

        job_queue.close
      end

      def shutdown
        @shutdown = true
      end
    end
  end
end
