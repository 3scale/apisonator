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

      def utilization(app_usage_reports)
        max_utilization = -1.0
        max_record = nil
        max = proc do |item|
          if item.max_value > 0
            utilization = item.current_value / item.max_value.to_f

            if utilization > max_utilization
              max_record = item
              max_utilization = utilization
            end
          end
        end

        app_usage_reports.each(&max)

        if max_utilization == -1
          ## case that all the limits have max_value==0
          max_utilization = 0
          max_record = app_usage_reports.first
        end

        [max_utilization, max_record]
      end

      def update_utilization(service_id, app_id, max_utilization, max_record, timestamp)
        discrete = utilization_discrete(max_utilization)

        keys = alert_keys(service_id, app_id, discrete)

        already_alerted, allowed = storage.pipelined do |pipeline|
          pipeline.get(keys[:already_notified])
          pipeline.sismember(keys[:allowed], discrete)
        end

        if already_alerted.nil? && allowed && discrete.to_i > 0
          next_id, _ = storage.pipelined do |pipeline|
            pipeline.incr(keys[:current_id])
            pipeline.setex(keys[:already_notified], ALERT_TTL, "1")
          end

          alert = { :id => next_id,
                    :utilization => discrete,
                    :max_utilization => max_utilization,
                    :application_id => app_id,
                    :service_id => service_id,
                    :timestamp => timestamp,
                    :limit => formatted_limit(max_record) }

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

      def formatted_limit(record)
        "#{record.metric_name} per #{record.period}: "\
        "#{record.current_value}/#{record.max_value}"
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
