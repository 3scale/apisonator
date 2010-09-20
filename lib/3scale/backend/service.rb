module ThreeScale
  module Backend
    class Service < Core::Service
      def self.load_id!(provider_key)
        load_id(provider_key) or raise ProviderKeyInvalid, provider_key
      end

      def self.load!(provider_key)
        load(provider_key) or raise ProviderKeyInvalid, provider_key
      end
    end
  end
end
