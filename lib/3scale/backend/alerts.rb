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

        def key_usage_already_checked(service_id, app_id)
          prefix = key_prefix(service_id, app_id)
          "#{prefix}usage_already_checked"
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

      # This class is useful to reduce the amount of information that we need to
      # fetch from Redis to determine whether an alert should be raised.
      # In summary, alerts are raised at the application level and we need to
      # wait for 24h before raising a new one for the same level (ALERTS_BIN
      # above).
      #
      # This class allows us to check all the usage limits once and then not
      # check all of them again (just the ones in the report job) until:
      # 1) A specific alert has expired (24h passed since it was triggered).
      # 2) A new alert bin is enabled for the service.
      class UsagesChecked
        extend KeyHelpers
        extend StorageHelpers
        include Memoizer::Decorator

        def self.need_to_check_all?(service_id, app_id)
          !storage.exists(key_usage_already_checked(service_id, app_id))
        end
        memoize :need_to_check_all?

        def self.mark_all_checked(service_id, app_id)
          ttl = ALERT_BINS.map do |bin|
            ttl = storage.ttl(key_already_notified(service_id, app_id, bin))

            # Redis returns -2 if key does not exist, and -1 if it exists without
            # a TTL (we know this should not happen for the alert bins).
            # In those cases we should just set the TTL to the max (ALERT_TTL).
            ttl >= 0 ? ttl : ALERT_TTL
          end.min

          storage.setex(key_usage_already_checked(service_id, app_id), ttl, '1'.freeze)
          Memoizer.clear(Memoizer.build_key(self, :need_to_check_all?, service_id, app_id))
        end

        def self.invalidate(service_id, app_id)
          storage.del(key_usage_already_checked(service_id, app_id))
        end

        def self.invalidate_for_service(service_id)
          app_ids = []
          cursor = 0

          loop do
            cursor, ids = storage.sscan(
              Application.applications_set_key(service_id), cursor, count: SCAN_SLICE
            )

            app_ids += ids

            break if cursor.to_i == 0
          end

          invalidate_batch(service_id, app_ids)
        end

        def self.invalidate_batch(service_id, app_ids)
          app_ids.each_slice(PIPELINED_SLICE_SIZE) do |ids|
            keys = ids.map { |app_id| key_usage_already_checked(service_id, app_id) }
            storage.del(keys)
          end
        end
        private_class_method :invalidate_batch
      end

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
          next_id, _, _ = storage.pipelined do
            storage.incr(keys[:current_id])
            storage.setex(keys[:already_notified], ALERT_TTL, "1")
            UsagesChecked.invalidate(service_id, app_id)
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
