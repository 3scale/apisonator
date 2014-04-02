require '3scale/backend/use_cases/provider_key_change_use_case'
require '3scale/backend/use_cases/service_user_management_use_case'

module ThreeScale
  module Backend
    class ServicesAPI < InternalAPI

      get '/:id' do
        if service = Service.load_by_id(params[:id])
          service.to_json
        else
          status 404
          {error: :not_found}.to_json
        end
      end

      post '/' do
        begin
          service = Service.save!(params[:service])
          status 201
          {service: service, status: :created}.to_json
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
          {service: service, status: :ok}.to_json
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
          Service.delete_by_id params[:id], force: (params[:force] == 'true')
          {status: :ok}.to_json
        rescue ServiceIsDefaultService => e
          respond_with_400 e
        end
      end

      get '/:id/users' do
        {count: user_use_case.count}.to_json
      end

      get '/:id/users/:username/exists' do
        if user_use_case.exists?
          {exists: true}.to_json
        else
          {exists: false}.to_json
        end
      end

      post '/:id/users/:username' do
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
