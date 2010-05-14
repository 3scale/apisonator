require '3scale/backend/storable'

module ThreeScale
  module Backend
    class Contract
      include Storable
      
      attr_accessor :service_id
      attr_accessor :user_key

      attr_accessor :id
      attr_accessor :state
      attr_accessor :plan_id
      attr_accessor :plan_name

      def self.load(service_id, user_key)
        key_prefix = "contract/service_id:#{service_id}/user_key:#{user_key}"

        values = storage.mget(encode_key("#{key_prefix}/id"),
                              encode_key("#{key_prefix}/state"),
                              encode_key("#{key_prefix}/plan_id"),
                              encode_key("#{key_prefix}/plan_name"))
        id, state, plan_id, plan_name = values

        id && new(:service_id => service_id,
                  :user_key   => user_key,
                  :id         => id,
                  :state      => state.to_sym,
                  :plan_id    => plan_id,
                  :plan_name  => plan_name)
      end

      def self.save(attributes)
        contract = new(attributes)
        contract.save
      end

      def save
        key_prefix = "contract/service_id:#{service_id}/user_key:#{user_key}"

        # TODO: the current redis client does not support multibulk command. When it's
        # improved, change this to a single mset.
        storage.set(encode_key("#{key_prefix}/id"), id)
        storage.set(encode_key("#{key_prefix}/state"), state.to_s)    if state
        storage.set(encode_key("#{key_prefix}/plan_id"), plan_id)     if plan_id
        storage.set(encode_key("#{key_prefix}/plan_name"), plan_name) if plan_name
      end

      def usage_limits
        UsageLimit.load_all(service_id, plan_id)
      end
    end
  end
end
