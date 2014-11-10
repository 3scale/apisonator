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
          attributes = params[:metric]
          halt 400, { status: :error, error: 'invalid parameter \'metric\'' }.to_json unless attributes
          attributes.merge!({service_id: service_id, id: id})
          metric = Metric.save attributes
          [201, headers, { status: :created, metric: metric.to_hash }.to_json]
        end

        put '/:id' do |service_id, id|
          attributes = params[:metric]
          halt 400, { status: :error, error: 'invalid parameter \'metric\'' }.to_json unless attributes
          attributes.merge!({service_id: service_id, id: id})
          metric = Metric.save attributes
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
