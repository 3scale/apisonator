module ThreeScale
  module Backend

    # This class uses Redis to implement a distributed lock.
    #
    # To implement the distributed lock, we use the Redis operation 'set nx'.
    # The locking algorithm is detailed here: http://redis.io/topics/distlock
    # Basically, every time that we want to use the lock, we generate a random
    # number and set a key in Redis with that random number if its current
    # value is null. If we could set the value, it means that we could get the
    # lock. To release it, we just need to set to delete the same key.
    #
    # The implementation used in this class has some limitations.
    # This is limited to a single Redis instance (through Twemproxy), and if
    # the master goes off the mutual exclusion basically does not exist
    # anymore. But there is another thing that breaks the mutual exclusion:
    # whatever we do within the lock critical section is racing against the
    # TTL, and we cannot guarantee that the section will be finished within the
    # limit of the TTL. It can be the case that even if we actually locked
    # Redis, the TTL would have expired before we got the response (think about
    # really bad network conditions or scheduling issues in the computer that
    # is running the critical section). So the lock acts more as an "advisory"
    # lock than a real lock: whatever we execute inside the critical section is
    # "probably going to be with mutual exclusion, but no guarantees".
    #
    # Possible ways to minimize the window of this race condition:
    #   1) Do all the work and just lock for committing.
    #   2) Use large values as TTLs as much as possible.
    class DistributedLock
      MAX_RANDOM = 1_000_000_000
      private_constant :MAX_RANDOM

      def initialize(resource, ttl, storage)
        @resource = resource
        @ttl = ttl
        @storage = storage
        @random = Random.new
      end

      # Returns key to unlock if the lock is acquired. Nil otherwise.
      def lock
        key = lock_key
        storage.set(lock_storage_key, key, nx: true, ex: ttl) ? key : nil
      end

      def unlock
        storage.del(lock_storage_key)
      end

      def current_lock_key
        storage.get(lock_storage_key)
      end

      private

      attr_reader :resource, :ttl, :storage, :random

      def lock_key
        random.rand(MAX_RANDOM).to_s
      end

      def lock_storage_key
        "#{resource.downcase}:lock".freeze
      end
    end
  end
end
