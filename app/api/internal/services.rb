require '3scale/backend/use_cases/provider_key_change_use_case'
require '3scale/backend/use_cases/cubert_service_management_use_case'

module ThreeScale
  module Backend
    module API
      internal_api '/services' do
        get '/:id' do
          if service = Service.load_by_id(params[:id])
            service.to_hash.to_json
          else
            [404, headers, {error: :not_found}.to_json]
          end
        end

        post '/' do
          begin
            service = Service.save!(params[:service])
            [201, headers, {service: service.to_hash, status: :created}.to_json]
          rescue ServiceRequiresDefaultUserPlan => e
            respond_with_400 e
          end
        end

        put '/:id' do
          begin
            service = Service.load_by_id(params[:id])
            if service
              params[:service].each do |attr, value|
                service.send "#{attr}=", value
              end
              service.save!
            else
              service = Service.save!(params[:service])
            end
            {service: service.to_hash, status: :ok}.to_json
          rescue ServiceRequiresDefaultUserPlan => e
            respond_with_400 e
          end
        end

        put '/change_provider_key/:key' do
          begin
            ProviderKeyChangeUseCase.new(params[:key], params[:new_key]).process
            {status: :ok}.to_json
          rescue InvalidProviderKeys, ProviderKeyExists, ProviderKeyNotFound => e
            respond_with_400 e
          end
        end

        delete '/:id' do
          begin
            Service.delete_by_id params[:id]
            {status: :deleted}.to_json
          rescue ServiceIsDefaultService => e
            respond_with_400 e
          rescue ServiceIdInvalid => e
            respond_with_404 e
          end
        end

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
