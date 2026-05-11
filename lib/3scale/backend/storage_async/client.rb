# frozen_string_literal: true

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

        DEFAULT_HOST = 'localhost'.freeze
        DEFAULT_PORT = 6379

        class << self
          attr_writer :instance

          def instance(reset = false)
            if reset || @instance.nil?
              @instance = new(
                  Storage::Helpers.config_with(
                      configuration.redis,
                      options: { default_url: "#{DEFAULT_HOST}:#{DEFAULT_PORT}" }
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
        #   storage.pipelined do |pipeline|
        #     pipeline.get('a')
        #     pipeline.get('b')
        #   end
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

        # Retries the block on connection errors without destroying the
        # client. The underlying pool already handles individual dead
        # connections by retiring them and creating new ones via its
        # constructor block (which re-resolves the master through
        # sentinels). We just need to wait before retrying so we don't
        # spin during a master failover.
        def with_reconnect
          attempt = 0
          begin
            yield connect
          rescue *CONNECTION_ERRORS => e
            if attempt < @opts[:reconnect_attempts]
              attempt += 1
              Backend.logger.warn "Redis connection lost, reconnecting (attempt #{attempt}/#{@opts[:reconnect_attempts]}): #{e.message}"
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
