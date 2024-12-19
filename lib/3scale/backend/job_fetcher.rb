# frozen_string_literal: true

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

      # The default redis_client is the one defined in Resque::Helpers
      def initialize(redis_client: redis, fetch_timeout: REDIS_TIMEOUT)
        @redis = redis_client
        @fetch_timeout = fetch_timeout
        @queues ||= QUEUES.map { |q| "queue:#{q}".freeze }.freeze
      end

      # @param wait [Boolean] wait for a job to appear in a queue instead of returning immediately
      # @param max [Integer] maximum number of records to return
      #   note: presently ignored in waiting mode because BLMPOP was added in Redis 7
      #   note: also we need to update redis-rb gem so that sync client can support this parameter
      # @return [nil, Resque::Job, Array<Resque::Job>] nil when no jobs are present in the queue,
      #                                                 a single job when max was not specified,
      #                                                 an array of jobs otherwise
      def fetch(wait: true, max: nil)
        queue, encoded_jobs = wait ? wait_pop_from_queue : try_pop_from_queue(max)
        return if !encoded_jobs || encoded_jobs.empty?

        # filter_map to ignore `decode_job` errors causing it to return `nil`
        jobs = encoded_jobs.filter_map { decode_job queue, _1 }

        jobs.count > 1 || max ? jobs : jobs.first
      end

      # Note: this method calls #close on job_queue after receiving #shutdown.
      # That signals to the caller that there won't be any more jobs.
      def start(job_queue)
        loop do
          break if @shutdown

          jobs = fetch(wait: false, max: Worker::DEFAULT_MAX_CONCURRENT_JOBS)

          # if there were no jobs, we can make a blocking call instead of reinventing waiting logic
          jobs = fetch(max: Worker::DEFAULT_MAX_CONCURRENT_JOBS) unless jobs

          jobs.each { job_queue.enq _1 } if jobs
        end
      rescue Exception => e
        Worker.logger.notify(e)
      ensure
        job_queue.close
      end

      def shutdown
        @shutdown = true
      end

      private

      # @param max [Integer] maximum number of records to return
      #   note: we need to update redis-rb gem so that sync client can also support getting multiple elements at once
      # @return [nil, Array(String, Array<String>)] `nil` if no results, otherwise an array
      #   where the first element is the queue and second is an array of entries
      def try_pop_from_queue(max=nil)
        max ||= 1

        # this would better be implemented with LMPOP but it was added in Redis 7
        @queues.each do |queue|
          result = @redis.lpop queue, max # we always want an array so always specify max
          if result && !result.empty?
            return [queue, result]
          end
        end

        nil
      end

      # @return [nil, Array(String, Array<String>)] single element in the form ["queue:name", ["encoded job json"]] or nil on queue timeout
      # @note to support multiple values we need Redis 7 with BLMPOP
      def wait_pop_from_queue
        queue, encoded = @redis.blpop(*@queues, timeout: @fetch_timeout)
        [queue, [encoded]] if encoded
      rescue RedisClient::ReadTimeoutError => _e
        # Ignore this exception, this happens because of a bug on redis-rb, when connecting to sentinels.
        # Check: https://github.com/redis/redis-rb/issues/1279
      end

      def decode_job(queue, encoded_job)
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
        Resque::Job.new(queue.delete_prefix("queue:"),
                        Yajl::Parser.parse(encoded_job, check_utf8: false))
      rescue Exception => e
        # I think that the only exception that can be raised here is
        # Yajl::ParseError. However, this is a critical part of the code so
        # we will capture all of them just to be safe.
        Worker.logger.notify(e)
        nil
      end
    end
  end
end
