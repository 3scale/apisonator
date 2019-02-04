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
          def instance(reset = false)
            if reset || @instance.nil?
              @instance = new(configuration.redis)
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
          @redis_async = Async::Redis::Client.new(endpoint)
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

        def pipelined(&block)
          # TODO
        end

        def close
          @redis_async.close
        end
      end

    end
  end
end
