module ThreeScale
  module Backend
    module Alerts
      extend self

      ALERT_TTL       = 24*3600 # 1 day (only one message per day)
      ## zero must be here and sorted, yes or yes
      ALERT_BINS      = [0, 50, 80, 90, 100, 120, 150, 200, 300]
      FIRST_ALERT_BIN = ALERT_BINS.first
      RALERT_BINS     = ALERT_BINS.reverse

      def list_allowed_limit(service_id)
        storage.smembers("alerts/service_id:#{service_id}/allowed_set")
      end

      def delete_allowed_limit(service_id, value)
        val = value.to_i
        key = "alerts/service_id:#{service_id}/allowed_set"
        storage.srem(key,val) if ALERT_BINS.member?(val) && val.to_s==value.to_s
        storage.smembers(key)
      end

      def add_allowed_limit(service_id, value)
        val = value.to_i
        key = "alerts/service_id:#{service_id}/allowed_set"
        storage.sadd(key,val) if ALERT_BINS.member?(val) && val.to_s==value.to_s
        storage.smembers(key)
      end

      def utilization(status)
        max_utilization = -1.0
        max_record = nil

        status.usage_reports.each do |item|
          if item.max_value > 0
            utilization = item.current_value / item.max_value.to_f

            if utilization > max_utilization
              max_record = item
              max_utilization = utilization
            end
          end
        end

        status.user_usage_reports.each do |item|
          if item.max_value>0
            utilization = item.current_value / item.max_value.to_f
            if utilization > max_utilization
              max_record = item
              max_utilization = utilization
            end
          end
        end

        if max_utilization == -1
          ## case that all the limits have max_value==0
          max_utilization = 0
          max_record = status.usage_reports.first
          max_record = status.user_usage_reports.first if max_record.nil?
        end

        [max_utilization, max_record]
      end

      def build_key(service_id, app_id = nil)
        "alerts/service_id:#{service_id}/#{app_id ? "app_id:#{app_id}/" : ''.freeze}"
      end

      def update_utilization(status, max_utilization, max_record, timestamp)
        discrete = utilization_discrete(max_utilization)
        max_utilization_i = (max_utilization * 100.0).round

        period_day = timestamp.beginning_of_cycle(:day).to_compact_s
        period_hour = timestamp.beginning_of_cycle(:hour).to_compact_s

        service_id = status.application.service_id
        app_id = status.application.id

        alerts_service_app = build_key(service_id, app_id)
        alerts_service = build_key(service_id)

        key = "#{alerts_service_app}#{period_day}/#{discrete}"
        key_notified = "#{alerts_service_app}#{discrete}/already_notified"
        key_allowed = "#{alerts_service}allowed_set"
        key_current_max = "#{alerts_service_app}#{period_hour}/current_max"
        key_last_time_period = "#{alerts_service_app}last_time_period"
        key_stats_utilization = "#{alerts_service_app}stats_utilization"

        ## key_notified does not have the period, it reacts to (service_id/app_id/discrete)
        tmp, already_alerted, allowed, current_max, last_time_period = storage.pipelined do
          storage.incrby(key,"1")
          storage.get(key_notified)
          storage.sismember(key_allowed,discrete)
          storage.get(key_current_max)
          storage.get(key_last_time_period)
        end

        ## update the status of utilization
        if (max_utilization_i > current_max.to_i)

          if (current_max.to_i == 0) && period_hour!=last_time_period
            ## the first one of the hour and not itself. This is only done once per hour

            if !last_time_period.nil?
              value = storage.get("#{alerts_service_app}#{last_time_period}/current_max")
              value = value.to_i
              if value > 0
                storage.pipelined do
                  storage.rpush(key_stats_utilization, "#{Time.parse_to_utc(last_time_period)},#{value}")
                  storage.ltrim(key_stats_utilization, 0, 24*7 - 1)
                end
              end
            end
          end

          storage.pipelined do
            storage.set(key_current_max,max_utilization_i)
            storage.set(key_last_time_period,period_hour)
          end
        end

        if already_alerted.nil? && allowed && discrete.to_i > 0
          next_id, tmp1, tmp2 = storage.pipelined do
            storage.incrby("alerts/current_id",1)
            storage.set(key_notified,"1")
            storage.expire(key_notified,ALERT_TTL)
          end

          alert = { :id => next_id,
                    :utilization => discrete,
                    :max_utilization => max_utilization,
                    :application_id => app_id,
                    :service_id => service_id,
                    :timestamp => timestamp,
                    :limit => "#{max_record.metric_name} per #{max_record.period}: #{max_record.current_value}/#{max_record.max_value}"}

          Backend::EventStorage::store(:alert, alert)
        end
      end

      def stats(service_id, application_id)
        key_stats = "#{build_key(service_id, application_id)}stats_utilization"
        list = storage.lrange(key_stats,0,-1)
              # format compact address,value
        return list
      end

      def utilization_discrete(utilization)
        u = utilization * 100.0
        # reverse search
        RALERT_BINS.find do |b|
          u >= b
        end || FIRST_ALERT_BIN
      end

      def storage
        Storage.instance
      end
    end
  end
end
