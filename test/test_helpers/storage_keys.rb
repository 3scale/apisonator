module TestHelpers
  module StorageKeys
    private

    def contract_key(service_id, contract_id, metric_id, period, time)
      "stats/{service:#{service_id}}/cinstance:#{contract_id}/metric:#{metric_id}/#{period}:#{time}"
    end
    
    def service_key(service_id, metric_id, period, time)
      "stats/{service:#{service_id}}/metric:#{metric_id}/#{period}:#{time}"
    end
  end
end
