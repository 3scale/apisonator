require '3scale/backend/use_cases/provider_key_change_use_case'

module ThreeScale
  module Backend
    module API
      internal_api '/services' do
        get '/:id' do
          service = Service.load_by_id(params[:id])
          if service
            { status: :found, service: service.to_hash }.to_json
          else
            [404, headers, {error: :not_found}.to_json]
          end
        end

        post '/' do
          svc_attrs = api_params Service
          service = Service.save!(svc_attrs)
          [201, headers, {service: service.to_hash, status: :created}.to_json]
        end

        put '/:id' do
          svc_attrs = api_params Service
          service = Service.load_by_id(params[:id])
          if service
            svc_attrs.each do |attr, value|
              service.send "#{attr}=", value
            end
            service.save!
          else
            service = Service.save!(svc_attrs)
          end
          {service: service.to_hash, status: :ok}.to_json
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
      end
    end
  end
end
