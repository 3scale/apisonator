require '3scale/backend/storable'

module ThreeScale
  module Backend
    class Contract
      include Storable

      attr_accessor :id
      attr_accessor :state
      attr_accessor :service_id
      attr_accessor :user_key

      def self.load(service_id, user_key)
        key_part = "service_id:#{service_id}/user_key:#{user_key}"

        id, state = storage.mget(encode_key("contract/id/#{key_part}"),
                                 encode_key("contract/state/#{key_part}"))

        id && state && new(:id => id, :state => state.to_sym,
                           :service_id => service_id, :user_key => user_key)
      end

      def self.save(attributes)
        contract = new(attributes)
        contract.save
      end

      def save
        key_part = "service_id:#{service_id}/user_key:#{user_key}"

        # TODO: the current redis client does not support multibulk command. When it's
        # improved, change this to a single mset.
        storage.set(encode_key("contract/id/#{key_part}"), id)
        storage.set(encode_key("contract/state/#{key_part}"), state.to_s)
      end
    end
  end
end
