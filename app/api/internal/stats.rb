module ThreeScale
  module Backend
    module API
      internal_api '/services/:service_id/stats' do
        before do
          respond_with_404('service not found') unless Service.exists?(params[:service_id])
        end

        # This is very slow and needs to be disabled until the performance
        # issues are solved. In the meanwhile, the job will just return OK.
=begin
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
=end

        # This is an alternative to the above. It just adds the service to a
        # Redis set to marked is as "to be deleted".
        # Later a script can read that set and actually delete the keys.
        # Read the docs of the Stats::Cleaner class for more details.
        #
        # Notice that this method ignores the "from" and "to" parameters. When
        # system calls this method, they're always interested in deleting all
        # the keys. They were just passing "from" and "to" to make the
        # implementation of the option above easier.
        delete '' do |service_id|
          Stats::Cleaner.mark_service_to_be_deleted(service_id)
          { status: :to_be_deleted }.to_json
        end
      end
    end
  end
end
