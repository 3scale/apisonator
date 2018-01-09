module ThreeScale
  module Backend
    module API
      internal_api '/services/:service_id/metrics' do
        get '/:id' do |service_id, id|
          metric = Metric.load service_id, id
          if metric
            { status: :found, metric: metric.to_hash }.to_json
          else
            [404, headers, { status: :not_found, error: 'metric not found' }.to_json]
          end
        end

        post '/:id' do |service_id, id|
          metric_attrs = api_params Metric 
          metric_attrs[:service_id] = service_id
          metric_attrs[:id] = id
          metric = Metric.save metric_attrs
          [201, headers, { status: :created, metric: metric.to_hash }.to_json]
        end

        put '/:id' do |service_id, id|
          metric_attrs = api_params Metric 
          metric_attrs[:service_id] = service_id
          metric_attrs[:id] = id
          metric = Metric.save metric_attrs
          { status: :modified, metric: metric.to_hash }.to_json
        end

        delete '/:id' do |service_id, id|
          if Metric.delete(service_id, id)
            { status: :deleted }.to_json
          else
            [404, headers, { status: :not_found, error: 'metric not found' }.to_json]
          end
        end
      end
    end
  end
end
