module ThreeScale
  module Backend
    class JobFetcher
      include Resque::Helpers

      # the order is relevant
      QUEUES = [:priority, :main, :stats].freeze
      private_constant :QUEUES

      REDIS_TIMEOUT = 60
      private_constant :REDIS_TIMEOUT

      # The default redis_client is the one defined in Resque::Helpers
      def initialize(redis_client: redis, fetch_timeout: REDIS_TIMEOUT)
        @redis = redis_client
        @fetch_timeout = fetch_timeout
        @queues ||= QUEUES.map { |q| "queue:#{q}" }
      end

      def fetch
        encoded_job = @redis.blpop(*@queues, timeout: @fetch_timeout)

        return nil if encoded_job.blank?

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
    end
  end
end
