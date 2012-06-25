module ThreeScale
  module Backend
    class Service < Core::Service

      # Returns true if a given service belongs to the provider with
      # that key without loading the whole object.
      #
      def self.authenticate_service_id(service_id, provider_key)
        provider_key == storage.get(storage_key(service_id, 'provider_key'))
      end

      def self.load_id!(provider_key)
        load_id(provider_key) or raise ProviderKeyInvalid, provider_key
      end

      def self.load!(provider_key)
        load(provider_key) or raise ProviderKeyInvalid, provider_key
      end

      def self.load_by_id!(service_id)
        load_by_id(service_id) or raise ServiceIdInvalid, service_id
      end

    end
  end
end
