module ThreeScale
  module Backend
    class Service
      include Storable
      include Configurable

      def self.save(attributes = {})
        storage.set(encode_key("service/provider_key:#{attributes[:provider_key]}/id"),
                    attributes[:id])
      end

      def self.load_id(provider_key)
        storage.get(encode_key("service/provider_key:#{provider_key}/id"))
      end
    end
  end
end
