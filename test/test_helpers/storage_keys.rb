module TestHelpers
  module StorageKeys
    private

    def application_key(service_id, application_id, metric_id, period, time = nil)
      "stats/{service:#{service_id}}/cinstance:#{application_id}/metric:#{metric_id}/#{period_part(period, time)}"
    end

    def service_key(service_id, metric_id, period, time = nil)
      "stats/{service:#{service_id}}/metric:#{metric_id}/#{period_part(period, time)}"
    end

    def response_code_key(service_id, response_code, period, time = nil)
      "stats/{service:#{service_id}}/response_code:#{response_code}/#{period_part(period, time)}"
    end

    def app_response_code_key(service_id, application_id, response_code, period, time = nil)
      "stats/{service:#{service_id}}/cinstance:#{application_id}/response_code:#{response_code}/#{period_part(period, time)}"
    end

    def period_part(period, time = nil)
      if period == :eternity
        'eternity'
      else
        "#{period}:#{time}"
      end
    end

    def app_keys_for_all_periods(service_id, app_id, metric_id, time)
      time_utc = time.getutc

      ThreeScale::Backend::Period::SYMBOLS.map do |period|
        application_key(
          service_id,
          app_id,
          metric_id,
          period,
          ThreeScale::Backend::Period::Boundary.start_of(period, time_utc).to_compact_s
        )
      end
    end
  end
end
