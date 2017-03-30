module ThreeScale
  module Backend
    module API
      internal_api '/services' do
        put '/:id/logs_bucket' do
          begin
            CubertServiceManagementUseCase.enable_service params[:id], params[:bucket]
            { status: :ok, bucket: CubertServiceManagementUseCase.bucket(params[:id]) }.to_json
          rescue BucketMissing => e
            respond_with_400 e
          end
        end

        delete '/:id/logs_bucket' do
          CubertServiceManagementUseCase.disable_service params[:id]
          { status: :deleted }.to_json
        end
      end
    end
  end
end
