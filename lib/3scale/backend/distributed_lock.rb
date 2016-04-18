module ThreeScale
  module Backend
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
