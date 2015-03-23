module TestHelpers
  module StorageKeys
    private

    def end_user_key(service_id, user_id, metric_id, period, time = nil)
      "stats/{service:#{service_id}}/uinstance:#{user_id}/metric:#{metric_id}/#{period_part(period, time)}"
    end

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

    def end_user_response_code_key(service_id, user_id, response_code, period, time = nil)
      "stats/{service:#{service_id}}/uinstance:#{user_id}/response_code:#{response_code}/#{period_part(period, time)}"
    end

    def period_part(period, time = nil)
      if period == :eternity
        'eternity'
      else
        "#{period}:#{time}"
      end
    end

  end
end
