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

        # TODO: the current redis client does not support multibulk commands. When it's
        # improved, change this to a single mset.
        storage.set(encode_key("#{key_prefix}/id"), id)
        storage.set(encode_key("#{key_prefix}/state"), state.to_s)    if state
        storage.set(encode_key("#{key_prefix}/plan_id"), plan_id)     if plan_id
        storage.set(encode_key("#{key_prefix}/plan_name"), plan_name) if plan_name
      end

      def usage_limits
        UsageLimit.load_all(service_id, plan_id)
      end

      def current_values
        pairs = usage_limits.map do |usage_limit|
          [usage_limit.metric_id, usage_limit.period]
        end

        return {} if pairs.empty?

        now = Time.now.getutc

        keys = pairs.map do |metric_id, period|
          usage_value_key(metric_id, period, now)
        end

        raw_values = storage.mget(*keys)
        values     = {}

        pairs.each_with_index do |(metric_id, period), index|
          values[period] ||= NumericHash.new
          values[period][metric_id] = raw_values[index].to_i
        end

        values
      end

      private

      def usage_value_key(metric_id, period, time)
        # TODO: extract this key generation out.
        encode_key("stats/{service:#{service_id}}/cinstance:#{id}/metric:#{metric_id}/" +
                   "#{period}:#{time.beginning_of_cycle(period).to_compact_s}")
      end
    end
  end
end
