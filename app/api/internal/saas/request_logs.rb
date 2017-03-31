module ThreeScale
  module Backend
    module API
      # This API should drop the bucket suffix, as it's really a detail
      # of a deprecated implementation.
      internal_api '/services' do
        put '/:id/logs_bucket' do
          # bucket is a deprecated optional param
          bucket = params[:bucket]
          RequestLogs::Management.enable_service params[:id]
          { status: :ok, bucket: bucket }.to_json
        end

        delete '/:id/logs_bucket' do
          RequestLogs::Management.disable_service params[:id]
          { status: :deleted }.to_json
        end
      end
    end
  end
end
