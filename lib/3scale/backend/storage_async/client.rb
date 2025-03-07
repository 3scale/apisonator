# frozen_string_literal: true

require '3scale/backend/async_redis/endpoint_helpers'
require '3scale/backend/async_redis/client'

module ThreeScale
  module Backend
    module StorageAsync

      # This is a wrapper for the Async-Redis client
      # (https://github.com/socketry/async-redis).
      # This class overrides some methods to provide the same interface that
      # the redis-rb client provides.
      # This is done to avoid modifying all the model classes which assume that
      # the Storage instance behaves likes the redis-rb client.
      class Client
        include Configurable
        include Methods

        class << self
          attr_writer :instance

          def instance(reset = false)
            if reset || @instance.nil?
              @instance = new(
                  Storage::Helpers.config_with(
                      configuration.redis,
                      options: { default_url: "#{AsyncRedis::EndpointHelpers::DEFAULT_HOST}:#{AsyncRedis::EndpointHelpers::DEFAULT_PORT}" }
                  )
              )
            else
              @instance
            end
          end
        end

        def initialize(opts)
          @opts = opts
          @redis_async = nil
        end

        def call(*args)
          with_reconnect do |conn|
            conn.call(*args)
          end
        end

        # This method allows us to send pipelines like this:
        # storage.pipelined do |pipeline|
        #   pipeline.get('a')
        #   pipeline.get('b')
        # end
        def pipelined(&block)
          # This replaces the client with a Pipeline that accumulates the Redis
          # commands run in a block and sends all of them in a single request.

          with_reconnect do |conn|
            pipeline = Pipeline.new
            block.call pipeline
            pipeline.run(conn)
          end
        end

        def connect
          @redis_async ||= AsyncRedis::Client.connect(@opts)
        end

        def close
          @redis_async&.close
          @redis_async = nil
        end

        private

        def with_reconnect
          attempt = 0
          begin
           yield connect
          rescue *CONNECTION_ERRORS => e
            close

            if attempt < @opts[:reconnect_attempts]
              attempt += 1
              sleep @opts[:reconnect_wait_seconds]
              retry
            else
              raise e
            end
          end
        end
      end
    end
  end
end
