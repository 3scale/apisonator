module ThreeScale
  module Backend
    class Application < Core::Application
      def self.load!(service_id, application_id)
        load(service_id, application_id) or raise ApplicationNotFound, application_id
      end

      def usage_limits
        UsageLimit.load_all(service_id, plan_id)
      end

      # Creates new application key and adds it to the list of keys of this application.
      # If +value+ is nil, generates new random key, otherwise uses the given value as
      # the new key.
      def create_key!(value = nil)
        value ||= SecureRandom.hex(16)
        storage.sadd(storage_key(:keys), value)
        value
      end

      # Deletes the given key if it exists, raises an exception if not.
      def delete_key!(value)
        raise ApplicationKeyNotFound, value unless has_key?(value)
        storage.srem(storage_key(:keys), value)
      end

      # Returns all application keys of this application.
      def keys
        storage.smembers(storage_key(:keys)) || []
      end

      # Returns true if there are no application keys, false otherwise.
      def keys_empty?
        storage.scard(storage_key(:keys)).to_i.zero?
      end

      # Returns true if the given key is among the keys of this application,
      # false otherwise.
      def has_key?(key)
        storage.sismember(storage_key(:keys), key)
      end

      def active?
        state == :active
      end
    end
  end
end
