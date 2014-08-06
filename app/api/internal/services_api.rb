require '3scale/backend/use_cases/provider_key_change_use_case'
require '3scale/backend/use_cases/service_user_management_use_case'

module ThreeScale
  module Backend
    class ServicesAPI < InternalAPI

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
          params[:service].each do |attr, value|
            service.send "#{attr}=", value
          end
          service.save!
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
        user_use_case.add
        {status: :ok}.to_json
      end

      delete '/:id/users/:username' do
        user_use_case.delete

        {status: :ok}.to_json
      end

      private

      def get_service
        service = Service.load_by_id(params[:id])
        service ? service : respond_with_404("Service #{params[:id]} not found")
      end

      def user_use_case
        ServiceUserManagementUseCase.new(get_service, params[:username])
      end

    end
  end
end
