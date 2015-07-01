module ThreeScale
  module Backend
    class AlertLimit
      module KeyHelpers
        def key(service_id)
          "alerts/service_id:#{service_id}/allowed_set"
        end
      end

      include KeyHelpers
      extend KeyHelpers

      include Storable

      attr_accessor :service_id, :value

      def save
        storage.sadd(key(service_id), value.to_i) if valid?
      end

      def to_hash
        {
          service_id: service_id,
          value:      value.to_i,
        }
      end

      def self.load_all(service_id)
        values = storage.smembers(key(service_id))
        values.map do |value|
          new(service_id: service_id, value: value.to_i)
        end
      end

      def self.save(service_id, value)
        alert_limit = new(service_id: service_id, value: value)
        alert_limit if alert_limit.save
      end

      def self.delete(service_id, value)
        storage.srem(key(service_id), value.to_i)
      end

      private

      def valid?
        val = value.to_i
        Alerts::ALERT_BINS.member?(val) && val.to_s == value.to_s
      end
    end
  end
end
