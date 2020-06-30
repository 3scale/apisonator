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
          @redis_async = Async::Redis::Client.new(
            endpoint, limit: opts[:max_connections]
          )
          @building_pipeline = false
        end

        # Now we are going to define the methods to run redis commands
        # following the interface of the redis-rb lib.
        #
        # These are the different cases:
        #   1) Methods that can be called directly. For example SET:
        #      @redis_async.call('SET', some_key)
        #   2) Methods that need to be "boolified". These are methods for which
        #      redis-rb returns a boolean, but redis just returns an integer.
        #      For example, Redis returns 0 or 1 for the EXISTS command, but
        #      redis-rb transforms that into a boolean.
        #   3) There are a few methods that need to be treated differently and
        #      do not fit in any of the previous categories. For example, SSCAN
        #      which accepts a hash of options in redis-rb.
        #
        # All of this might be simplified a bit in the future using the
        # "methods" in async-redis
        # https://github.com/socketry/async-redis/tree/master/lib/async/redis/methods
        # but there are some commands missing, so for now, that's not an option.

        METHODS_TO_BE_CALLED_DIRECTLY = [
          :del,
          :expire,
          :expireat,
          :flushdb,
          :get,
          :hset,
          :hmget,
          :incr,
          :incrby,
          :keys,
          :llen,
          :lpop,
          :lpush,
          :lrange,
          :ltrim,
          :mget,
          :ping,
          :rpush,
          :scard,
          :setex,
          :smembers,
          :sunion,
          :ttl,
          :zcard,
          :zrangebyscore,
          :zremrangebyscore,
          :zrevrange
        ].freeze
        private_constant :METHODS_TO_BE_CALLED_DIRECTLY

        METHODS_TO_BE_CALLED_DIRECTLY.each do |method|
          define_method(method) do |*args|
            @redis_async.call(method, *args.flatten)
          end
        end

        METHODS_TO_BOOLIFY = [
          :exists,
          :sismember,
          :sadd,
          :srem,
          :zadd
        ].freeze
        private_constant :METHODS_TO_BOOLIFY

        METHODS_TO_BOOLIFY.each do |method|
          define_method(method) do |*args|
            @redis_async.call(method, *args.flatten) > 0
          end
        end

        def blpop(*args)
          call_args = ['BLPOP'] + args

          # redis-rb accepts a Hash as last arg that can contain :timeout.
          if call_args.last.is_a? Hash
            timeout = call_args.pop[:timeout]
            call_args << timeout
          end

          @redis_async.call(*call_args.flatten)
        end

        def set(key, val, opts = {})
          args = ['SET', key, val]

          args += ['EX', opts[:ex]] if opts[:ex]
          args << 'NX' if opts[:nx]

          @redis_async.call(*args)
        end

        def sscan(key, cursor, opts = {})
          args = ['SSCAN', key, cursor]

          args += ['MATCH', opts[:match]] if opts[:match]
          args += ['COUNT', opts[:count]] if opts[:count]

          @redis_async.call(*args)
        end

        def scan(cursor, opts = {})
          args = ['SCAN', cursor]

          args += ['MATCH', opts[:match]] if opts[:match]
          args += ['COUNT', opts[:count]] if opts[:count]

          @redis_async.call(*args)
        end

        # This method allows us to send pipelines like this:
        # storage.pipelined do
        #   storage.get('a')
        #   storage.get('b')
        # end
        def pipelined(&block)
          # This replaces the client with a Pipeline that accumulates the Redis
          # commands run in a block and sends all of them in a single request.
          #
          # There's an important limitation: this assumes that the fiber will
          # not yield in the block.

          # When running a nested pipeline, we just need to continue
          # accumulating commands.
          if @building_pipeline
            block.call
            return
          end

          @building_pipeline = true

          original = @redis_async
          pipeline = Pipeline.new
          @redis_async = pipeline

          begin
            block.call
          ensure
            @redis_async = original
            @building_pipeline = false
          end

          pipeline.run(original)
        end

        def close
          @redis_async.close
        end
      end

    end
  end
end
