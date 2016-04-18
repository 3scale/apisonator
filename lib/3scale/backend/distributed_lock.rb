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
    # The random number that we use is the current unix epoch in ms. This does
    # not ensure 100% that the locking algorithm works correctly. Also, the
    # implementation used in this class does not ensure a correct behavior if
    # for some reason one of the Redis masters fails and a slave takes its
    # place. However, in the jobs where we are currently using a distributed
    # lock, this is not an issue. For example, in the case of Kinesis jobs,
    # we assume that we can have duplicated events in S3. It is not a problem
    # because the way those events are later imported into Redshift ensures
    # that they are not imported twice.
    #
    # If for some reason we fail to delete the key associated to the lock in
    # the storage, there is the risk of not releasing the lock ever.
    # We solve this setting a TTL.
    class DistributedLock
      def initialize(resource, ttl, storage)
        @resource = resource
        @ttl = ttl
        @storage = storage
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

      attr_reader :resource, :ttl, :storage

      def lock_key
        DateTime.now.strftime('%Q')
      end

      def lock_storage_key
        "#{resource.downcase}:lock".freeze
      end
    end
  end
end
