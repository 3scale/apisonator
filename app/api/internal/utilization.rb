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
          app_utilization = Transactor.utilization(service_id, app_id)

          usage_report = app_utilization[0].map(&:to_h)

          max_usage_report = max_utilization = nil
          unless usage_report.empty?
            max_usage_report = app_utilization[1].to_h
            max_utilization = app_utilization[2]
          end

          stats = app_utilization[3].map do |stats_entry|
            timestamp, usage = stats_entry.split(',')
            { timestamp: timestamp, usage: usage.to_i }
          end

          { status: :found,
            utilization: {
              usage_report: usage_report,
              max_usage_report: max_usage_report,
              max_utilization: max_utilization,
              stats: stats } }.to_json
        end
      end
    end
  end
end
