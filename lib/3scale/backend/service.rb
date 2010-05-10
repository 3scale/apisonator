require '3scale/backend/storable'

module ThreeScale
  module Backend
    class Service
      include Storable

      def self.save(attributes = {})
        storage.set(encode_key("service/id/provider_key:#{attributes[:provider_key]}"),
                    attributes[:id])
      end

      def self.load_id(provider_key)
        storage.get(encode_key("service/id/provider_key:#{provider_key}"))
      end
    end
  end
end
