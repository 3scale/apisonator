module TestHelpers
  module StorageKeys
    private

    def application_key(service_id, application_id, metric_id, period, time = nil)
      "stats/{service:#{service_id}}/cinstance:#{application_id}/metric:#{metric_id}/#{period_part(period, time)}"
    end
    
    def service_key(service_id, metric_id, period, time = nil)
      "stats/{service:#{service_id}}/metric:#{metric_id}/#{period_part(period, time)}"
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
