module ThreeScale
  module Backend
    module API
      internal_api '/services/:service_id/stats' do
        before do
          respond_with_404('service not found') unless Service.exists?(params[:service_id])
        end

        delete '' do |service_id|
          delete_stats_job_attrs = api_params Stats::DeleteJobDef
          delete_stats_job_attrs[:service_id] = service_id
          delete_stats_job_attrs[:from] = delete_stats_job_attrs[:from].to_i
          delete_stats_job_attrs[:to] = delete_stats_job_attrs[:to].to_i
          begin
            Stats::DeleteJobDef.new(delete_stats_job_attrs).run_async
          rescue DeleteServiceStatsValidationError => e
            [400, headers, { status: :error, error: e.message }.to_json]
          else
            { status: :to_be_deleted }.to_json
          end
        end
      end
    end
  end
end
