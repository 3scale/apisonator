module ThreeScale
  module Backend
    class AlertLimit
      include Alerts::KeyHelpers
      extend Alerts::KeyHelpers

      include Storable

      attr_accessor :service_id, :value

      def save
        storage.sadd?(key_allowed_set(service_id), value.to_i) if valid?
      end

      def to_hash
        {
          service_id: service_id,
          value:      value.to_i,
        }
      end

      def self.load_all(service_id)
        values = storage.smembers(key_allowed_set(service_id))
        values.map do |value|
          new(service_id: service_id, value: value.to_i)
        end
      end

      def self.save(service_id, value)
        alert_limit = new(service_id: service_id, value: value)
        alert_limit if alert_limit.save
      end

      def self.delete(service_id, value)
        storage.srem?(key_allowed_set(service_id), value.to_i) if valid_value?(value)
      end

      def self.valid_value?(value)
        val = value.to_i
        Alerts::ALERT_BINS.include?(val) && val.to_s == value.to_s
      end

      private

      def valid?
        self.class.valid_value?(value)
      end
    end
  end
end
