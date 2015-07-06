require '3scale/backend/alert_limit'

module ThreeScale
  module Backend
    module API
      internal_api '/services/:service_id/alert_limits' do
        get '/' do |service_id|
          limits = AlertLimit.load_all(service_id)
          { status: :found, alert_limits: limits.map(&:to_hash) }.to_json
        end

        post '/' do |service_id|
          value = params.fetch(:alert_limit, {}).fetch(:value, nil)
          limit = AlertLimit.save(service_id, value)
          if limit
            [201, headers, { status: :created, alert_limit: limit.to_hash }.to_json]
          else
            halt 400, { error: "alert limit is invalid" }.to_json
          end
        end

        delete '/:value' do |service_id, value|
          if AlertLimit.delete(service_id, value)
            { status: :deleted }.to_json
          else
            [404, headers, { status: :not_found, error: 'alert limit not found' }.to_json]
          end
        end
      end
    end
  end
end
