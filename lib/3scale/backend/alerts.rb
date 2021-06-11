module ThreeScale
  module Backend
    module Alerts
      module KeyHelpers
        private

        # The compacted hour in the params refers to the
        # TimeHacks.to_compact_s method.
        def alert_keys(service_id, app_id, discrete_utilization)
          {
            already_notified: key_already_notified(service_id, app_id, discrete_utilization),
            allowed: key_allowed_set(service_id),
            current_id: key_current_id
          }
        end

        def key_prefix(service_id, app_id = nil)
          prefix = "alerts/service_id:#{service_id}/"
          prefix << "app_id:#{app_id}/" if app_id
          prefix
        end

        def key_already_notified(service_id, app_id, discrete_utilization)
          prefix = key_prefix(service_id, app_id)
          "#{prefix}#{discrete_utilization}/already_notified"
        end

        def key_allowed_set(service_id)
          prefix = key_prefix(service_id)
          "#{prefix}allowed_set"
        end

        def key_current_id
          'alerts/current_id'.freeze
        end
      end

      extend self
      extend KeyHelpers
      include Memoizer::Decorator

      ALERT_TTL       = 24*3600 # 1 day (only one message per day)
      ## zero must be here and sorted, yes or yes
      ALERT_BINS      = [0, 50, 80, 90, 100, 120, 150, 200, 300].freeze
      FIRST_ALERT_BIN = ALERT_BINS.first
      RALERT_BINS     = ALERT_BINS.reverse.freeze

      def can_raise_more_alerts?(service_id, app_id)
        allowed_bins = allowed_set_for_service(service_id).sort

        return false if allowed_bins.empty?

        # If the bin with the highest value has already been notified, there's
        # no need to notify anything else.
        not notified?(service_id, app_id, allowed_bins.last)
      end

      def update_utilization(service_id, app_id, utilization)
        discrete = utilization_discrete(utilization.ratio)

        keys = alert_keys(service_id, app_id, discrete)

        already_alerted, allowed = storage.pipelined do
          storage.get(keys[:already_notified])
          storage.sismember(keys[:allowed], discrete)
        end

        if already_alerted.nil? && allowed && discrete.to_i > 0
          next_id, _ = storage.pipelined do
            storage.incr(keys[:current_id])
            storage.setex(keys[:already_notified], ALERT_TTL, "1")
          end

          alert = { :id => next_id,
                    :utilization => discrete,
                    :max_utilization => utilization.ratio,
                    :application_id => app_id,
                    :service_id => service_id,
                    :timestamp => Time.now.utc,
                    :limit => utilization.to_s }

          Backend::EventStorage::store(:alert, alert)
        end
      end

      def utilization_discrete(utilization)
        u = utilization * 100.0
        # reverse search
        RALERT_BINS.find do |b|
          u >= b
        end || FIRST_ALERT_BIN
      end

      def allowed_set_for_service(service_id)
        storage.smembers(key_allowed_set(service_id)).map(&:to_i) # Redis returns strings always
      end
      memoize :allowed_set_for_service

      def notified?(service_id, app_id, bin)
        storage.get(key_already_notified(service_id, app_id, bin))
      end
      memoize :notified?

      def storage
        Storage.instance
      end
    end
  end
end
