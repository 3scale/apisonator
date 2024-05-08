require 'async/io'
require 'async/redis/client'
require 'async/redis/sentinels'

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
                      options: { default_url: "#{DEFAULT_HOST}:#{DEFAULT_PORT}" }
                  )
              )
            else
              @instance
            end
          end
        end

        def initialize(opts)
          @redis_async = initialize_client(opts)
        end

        def call(*args)
          @redis_async.call(*args)
        end

        # This method allows us to send pipelines like this:
        # storage.pipelined do |pipeline|
        #   pipeline.get('a')
        #   pipeline.get('b')
        # end
        def pipelined(&block)
          # This replaces the client with a Pipeline that accumulates the Redis
          # commands run in a block and sends all of them in a single request.

          pipeline = Pipeline.new
          block.call pipeline
          pipeline.run(@redis_async)
        end

        def close
          @redis_async.close
        end

        private

        DEFAULT_HOST = 'localhost'.freeze
        DEFAULT_PORT = 6379

        def initialize_client(opts)
          return init_host_client(opts) unless opts.key? :sentinels

          init_sentinels_client(opts)
        end

        def init_host_client(opts)
          uri = URI(opts[:url] || '')
          host = uri.host || DEFAULT_HOST
          port = uri.port || DEFAULT_PORT

          endpoint = Async::IO::Endpoint.tcp(host, port)
          Async::Redis::Client.new(endpoint, limit: opts[:max_connections])
        end

        def init_sentinels_client(opts)
          uri = URI(opts[:url] || '')
          name = uri.host
          role = opts[:role] || :master

          Async::Redis::SentinelsClient.new(name, opts[:sentinels], role)
        end
      end
    end
  end
end
