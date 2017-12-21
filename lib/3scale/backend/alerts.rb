module ThreeScale
  module Backend
    module Alerts
      module KeyHelpers
        private

        # The compacted hour and day in the params refer to the
        # TimeHacks.to_compact_s method.
        def alert_keys(service_id, app_id, discrete_utilization,
                       compacted_day_start, compacted_hour_start)
          {
            hits_per_day_and_discrete_utilization: key_hits_day_and_discr_util(
                service_id, app_id, compacted_day_start, discrete_utilization),
            already_notified: key_already_notified(service_id, app_id, discrete_utilization),
            allowed: key_allowed_set(service_id),
            current_max: key_current_max(service_id, app_id, compacted_hour_start),
            last_time_period: key_last_time_period(service_id, app_id),
            stats_utilization: key_stats_utilization(service_id, app_id),
            current_id: key_current_id
          }
        end

        def key_prefix(service_id, app_id = nil)
          prefix = "alerts/service_id:#{service_id}/"
          prefix << "app_id:#{app_id}/" if app_id
          prefix
        end

        def key_hits_day_and_discr_util(service_id, app_id,
                                        compacted_day_start, discrete_utilization)
          prefix = key_prefix(service_id, app_id)
          "#{prefix}#{compacted_day_start}/#{discrete_utilization}"
        end

        def key_already_notified(service_id, app_id, discrete_utilization)
          prefix = key_prefix(service_id, app_id)
          "#{prefix}#{discrete_utilization}/already_notified"
        end

        def key_allowed_set(service_id)
          prefix = key_prefix(service_id)
          "#{prefix}allowed_set"
        end

        def key_current_max(service_id, app_id, compacted_hour_start)
          prefix = key_prefix(service_id, app_id)
          "#{prefix}#{compacted_hour_start}/current_max"
        end

        def key_last_time_period(service_id, app_id)
          prefix = key_prefix(service_id, app_id)
          "#{prefix}last_time_period"
        end

        def key_stats_utilization(service_id, app_id)
          prefix = key_prefix(service_id, app_id)
          "#{prefix}stats_utilization"
        end

        def key_current_id
          'alerts/current_id'.freeze
        end
      end

      extend self
      extend KeyHelpers

      ALERT_TTL       = 24*3600 # 1 day (only one message per day)
      ## zero must be here and sorted, yes or yes
      ALERT_BINS      = [0, 50, 80, 90, 100, 120, 150, 200, 300].freeze
      FIRST_ALERT_BIN = ALERT_BINS.first
      RALERT_BINS     = ALERT_BINS.reverse.freeze

      def utilization(app_usage_reports, user_usage_reports)
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
        user_usage_reports.each(&max)

        if max_utilization == -1
          ## case that all the limits have max_value==0
          max_utilization = 0
          max_record = app_usage_reports.first || user_usage_reports.first
        end

        [max_utilization, max_record]
      end

      def update_utilization(service_id, app_id, max_utilization, max_record, timestamp)
        discrete = utilization_discrete(max_utilization)
        max_utilization_i = (max_utilization * 100.0).round

        beginning_of_day = Period::Boundary.day_start(timestamp)
        period_day = beginning_of_day.to_compact_s
        period_hour = Period::Boundary.hour_start(timestamp).to_compact_s
        # UNIX timestamp for key expiration - add 1 day + 5 mins
        expire_at = (beginning_of_day + 86700).to_i

        keys = alert_keys(service_id, app_id, discrete, period_day, period_hour)

        _, already_alerted, allowed, current_max, last_time_period, _, _ = storage.pipelined do
          storage.incr(keys[:hits_per_day_and_discrete_utilization])
          storage.get(keys[:already_notified])
          storage.sismember(keys[:allowed], discrete)
          storage.get(keys[:current_max])
          storage.get(keys[:last_time_period])
          storage.expireat(keys[:hits_per_day_and_discrete_utilization], expire_at)
          storage.expireat(keys[:current_max], expire_at)
        end

        ## update the status of utilization
        if max_utilization_i > current_max.to_i

          if (current_max.to_i == 0) && period_hour != last_time_period
            ## the first one of the hour and not itself. This is only done once per hour

            if !last_time_period.nil?
              value = storage.get(key_current_max(service_id, app_id, last_time_period))
              value = value.to_i
              if value > 0
                storage.pipelined do
                  storage.rpush(keys[:stats_utilization],
                                "#{Time.parse_to_utc(last_time_period)},#{value}")
                  storage.ltrim(keys[:stats_utilization], 0, 24*7 - 1)
                end
              end
            end
          end

          storage.pipelined do
            storage.set(keys[:current_max], max_utilization_i)
            storage.set(keys[:last_time_period], period_hour)
          end
        end

        if already_alerted.nil? && allowed && discrete.to_i > 0
          next_id, _, _ = storage.pipelined do
            storage.incr(keys[:current_id])
            storage.set(keys[:already_notified], "1")
            storage.expire(keys[:already_notified], ALERT_TTL)
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

      def storage
        Storage.instance
      end
    end
  end
end
