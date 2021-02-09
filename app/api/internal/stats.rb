module ThreeScale
  module Backend
    module API
      internal_api '/services/:service_id/stats' do
        before do
          respond_with_404('service not found') unless Service.exists?(params[:service_id])
        end

        # This adds the service to a Redis set to mark is as "to be deleted".
        # Later a script can read that set and actually delete the keys. Read
        # the docs of the Stats::Cleaner class for more details.
        #
        # Notice that this method ignores the "from" and "to" parameters used in
        # previous versions. When system calls this method, they're always
        # interested in deleting all the keys.
        delete '' do |service_id|
          Stats::Cleaner.mark_service_to_be_deleted(service_id)
          { status: :to_be_deleted }.to_json
        end
      end
    end
  end
end
