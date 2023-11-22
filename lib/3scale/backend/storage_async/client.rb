require 'concurrent'
require 'async/io'
require 'async/redis/client'

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
        private_constant :DEFAULT_HOST

        DEFAULT_PORT = 22121
        private_constant :DEFAULT_PORT

        HOST_PORT_REGEX = /redis:\/\/(.*):(\d+)/
        private_constant :HOST_PORT_REGEX

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
          host, port = opts[:url].match(HOST_PORT_REGEX).captures if opts[:url]
          host ||= DEFAULT_HOST
          port ||= DEFAULT_PORT

          endpoint = Async::IO::Endpoint.tcp(host, port)
          @redis_async = Concurrent::ThreadLocalVar.new{ Async::Redis::Client.new(
            endpoint, limit: opts[:max_connections]
          )}
        end

        def call(*args)
          @redis_async.value.call(*args)
        end

        # This method allows us to send pipelines like this:
        # storage.pipelined do |pipeline|
        #   pipeline.get('a')
        #   pipeline.get('b')
        # end
        def pipelined(&block)
          # This replaces the client with a Pipeline that accumulates the Redis
          # commands run in a block and sends all of them in a single request.
          #
          # There's an important limitation: this assumes that the fiber will
          # not yield in the block.

          pipeline = Pipeline.new
          block.call pipeline
          pipeline.run(@redis_async.value)
        end

        def close
          @redis_async.value.close
        end
      end

    end
  end
end
