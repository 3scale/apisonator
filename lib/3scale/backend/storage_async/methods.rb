# frozen_string_literal: true

module ThreeScale
  module Backend
    module StorageAsync
      module Methods
        # Now we are going to define the methods to run redis commands
        # following the interface of the redis-rb lib.
        #
        # These are the different cases:
        #   1) Methods that can be called directly. For example SET:
        #      call('SET', some_key)
        #   2) Methods that need to be "boolified". These are methods for which
        #      redis-rb returns a boolean, but redis just returns an integer.
        #      For example, Redis returns 0 or 1 for the EXISTS command, but
        #      redis-rb transforms that into a boolean.
        #   3) There are a few methods that need to be treated differently and
        #      do not fit in any of the previous categories. For example, SSCAN
        #      which accepts a hash of options in redis-rb.
        #
        # All of this might be simplified a bit in the future using
        # https://github.com/socketry/protocol-redis

        METHODS_TO_BE_CALLED_DIRECTLY = [
          :brpoplpush,
          :del,
          :exists,
          :expire,
          :expireat,
          :flushdb,
          :get,
          :hset,
          :hmget,
          :incr,
          :incrby,
          :keys,
          :lindex,
          :llen,
          :lpop,
          :lpush,
          :lrange,
          :lrem,
          :lset,
          :ltrim,
          :mget,
          :ping,
          :rpush,
          :sadd,
          :scard,
          :setex,
          :smembers,
          :srem,
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
            call(method, *args.flatten)
          end
        end

        METHODS_TO_BOOLIFY = [
          :exists?,
          :sismember,
          :sadd?,
          :srem?,
          :zadd
        ].freeze
        private_constant :METHODS_TO_BOOLIFY

        METHODS_TO_BOOLIFY.each do |method|
          command = method.to_s.delete('?')
          define_method(method) do |*args|
            call(command, *args.flatten) > 0
          end
        end

        def blpop(*args)
          call_args = ['BLPOP'] + args

          # redis-rb accepts a Hash as last arg that can contain :timeout.
          if call_args.last.is_a? Hash
            timeout = call_args.pop[:timeout]
            call_args << timeout
          end

          call(*call_args.flatten)
        end

        def set(key, val, opts = {})
          args = ['SET', key, val]

          args += ['EX', opts[:ex]] if opts[:ex]
          args << 'NX' if opts[:nx]

          call(*args)
        end

        def sscan(key, cursor, opts = {})
          args = ['SSCAN', key, cursor]

          args += ['MATCH', opts[:match]] if opts[:match]
          args += ['COUNT', opts[:count]] if opts[:count]

          call(*args)
        end

        def scan(cursor, opts = {})
          args = ['SCAN', cursor]

          args += ['MATCH', opts[:match]] if opts[:match]
          args += ['COUNT', opts[:count]] if opts[:count]

          call(*args)
        end
      end
    end
  end
end
