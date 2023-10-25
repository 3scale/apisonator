# The async lib does not work well with the Resque gem. It crashes when running
# a pipeline in the enqueue method.
# This module mokey-patches that method.

module ThreeScale
  module Backend
    module StorageAsync
      module ResqueExtensions
        def enqueue(klass, *args)
          queue = queue_from_class(klass)

          # The redis client is hidden inside a data store that contains a
          # namespace that contains the redis client. Both vars are called
          # "redis".
          async_client = Resque.redis.instance_variable_get(:@redis).instance_variable_get(:@redis)

          # We need to add the "resque" namespace in the keys for all the
          # commands.
          async_client.pipelined do |pipeline|
            pipeline.sadd('resque:queues', queue.to_s)
            pipeline.rpush(
              "resque:queue:#{queue}", Resque.encode(:class => klass.to_s, :args => args)
            )
          end
        end
      end
    end
  end
end

