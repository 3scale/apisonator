module ThreeScale
  module Backend
    module API
      internal_api '/services/:service_id/applications/:app_id/utilization' do
        before do
          unless Service.exists?(params[:service_id])
            respond_with_404('service not found')
          end

          unless Application.exists?(params[:service_id], params[:app_id])
            respond_with_404('application not found')
          end
        end

        get '/' do |service_id, app_id|
          utilization = Transactor.utilization(service_id, app_id)

          # app_utilization is an Array with 4 elements. We just want need to
          # return the first one as it is the only used in multi-tenant.
          usage_reports = utilization[0].map(&:to_h)
          { status: :found, utilization: usage_reports }.to_json
        end
      end
    end
  end
end
