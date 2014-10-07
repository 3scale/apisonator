require '3scale/backend/use_cases/provider_key_change_use_case'
require '3scale/backend/use_cases/service_user_management_use_case'

module ThreeScale
  module Backend
    module API
      internal_api '/services' do
        module ServiceHelpers
          def self.user_use_case(id, username)
            service = Service.load_by_id(id)
            ServiceUserManagementUseCase.new(service, username) if service
          end
        end

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
            {status: :ok}.to_json
          rescue ServiceIsDefaultService => e
            respond_with_400 e
          rescue ServiceIdInvalid => e
            respond_with_404 e
          end
        end

        post '/:id/users' do
          use_case = ServiceHelpers.user_use_case(params[:id], params[:username])
          respond_with_404("Service #{params[:id]} not found") unless use_case

          use_case.add
          {status: :ok}.to_json
        end

        delete '/:id/users/:username' do
          use_case = ServiceHelpers.user_use_case(params[:id], params[:username])
          respond_with_404("Service #{params[:id]} not found") unless use_case

          use_case.delete
          {status: :ok}.to_json
        end

      end
    end
  end
end
