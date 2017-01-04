module ThreeScale
  module Backend
    module API
      internal_api '/services' do
        put '/:id/logs_bucket' do
          begin
            service = CubertServiceManagementUseCase.new(params[:id])
            service.enable_service params[:bucket]
            {status: :ok, bucket: service.bucket}.to_json
          rescue BucketMissing => e
            respond_with_400 e
          end
        end

        delete '/:id/logs_bucket' do
          CubertServiceManagementUseCase.new(params[:id]).disable_service
          {status: :deleted}.to_json
        end
      end
    end
  end
end
