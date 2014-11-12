module ThreeScale
  module Backend
    module API
      internal_api '/services/:service_id/plans/:plan_id/usagelimits' do
        module UsageLimitsHelper
          def self.to_hash(service_id, plan_id, metric_id, period, value)
            {
              :service_id => service_id,
              :plan_id => plan_id,
              :metric_id => metric_id,
              period.to_sym => value
            }
          end
        end

        get '/:metric_id/:period' do |service_id, plan_id, metric_id, period|
          value = UsageLimit.load_value(service_id, plan_id, metric_id, period)
          if value
            { status: :found, usagelimit: UsageLimitsHelper.to_hash(service_id, plan_id,
                                                                   metric_id, period,
                                                                   value) }.to_json
          else
            [404, headers, { status: :not_found, error: 'usagelimit not found' }.to_json]
          end
        end

        put '/:metric_id/:period' do |service_id, plan_id, metric_id, period|
          attributes = params[:usagelimit]
          halt 400, { status: :error, error: 'invalid parameter \'usagelimit\'' }.to_json unless attributes
          value = attributes[period.to_sym]
          halt 400, { status: :error, error: "missing parameter '#{period}'" }.to_json unless value
          ul_hash = UsageLimitsHelper.to_hash(service_id, plan_id, metric_id, period, value)
          UsageLimit.save(ul_hash)
          { status: :modified, usagelimit: ul_hash }.to_json
        end

        delete '/:metric_id/:period' do |service_id, plan_id, metric_id, period|
          UsageLimit.delete(service_id, plan_id, metric_id, period)
          { status: :deleted }.to_json
        end

      end
    end
  end
end
