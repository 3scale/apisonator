module ThreeScale
  module Backend
    class Service < Core::Service

      # Returns true if a given service belongs to the provider with
      # that key without loading the whole object.
      #
      def self.authenticate_service_id(service_id, provider_key)
        key = "Service.authenticate_service_id-#{service_id}-#{provider_key}"
        Memoizer.memoize_block(key) do
          provider_key == storage.get(storage_key(service_id, 'provider_key'))
        end
      end

      def self.load_id!(provider_key)
        key = "Service.load_id!-#{provider_key}"
        Memoizer.memoize_block(key) do
          load_id(provider_key) or raise ProviderKeyInvalid, provider_key
        end
      end

      def self.load(provider_key)
        key = "Service.load-#{provider_key}"
        Memoizer.memoize_block(key) do
          super(provider_key)
        end
      end

      def self.load!(provider_key)
        key = "Service.load!-#{provider_key}"
        Memoizer.memoize_block(key) do
          load(provider_key) or raise ProviderKeyInvalid, provider_key
        end
      end

      def self.load_by_id!(service_id)
        key = "Service.load_by_id!-#{service_id}"
        Memoizer.memoize_block(key) do
          load_by_id(service_id) or raise ServiceIdInvalid, service_id
        end
      end

      def self.load_by_id(service_id)
        key = "Service.load_by_id-#{service_id}"
        Memoizer.memoize_block(key) do
          super(service_id)
        end
      end

      def self.list(provider_key)
        key = "Service.list-#{provider_key}"
        Memoizer.memoize_block(key) do
          storage.smembers(id_storage_key_set(provider_key)) || []
        end
      end

    end
  end
end
