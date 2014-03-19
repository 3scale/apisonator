module ThreeScale
  module Backend
    class ServicesAPI < InternalAPI
      ACCEPTED_PARAMS = %w(id service provider_key force)

      before do
        content_type 'application/json'
      end

      get '/' do
        Service.list(params['provider_key']).to_json
      end

      get '/:id' do
        Service.load_by_id(params[:id]).to_json
      end

      post '/' do
        service = Service.save!(params[:service])
        status 201
        {service: service, status: :created}.to_json
      end

      put '/:id' do
        service = Service.load_by_id(params[:id])
        params[:service].each do |attr, value|
          service.send "#{attr}=", value
        end
        service.save!
        {service: service, status: :ok}.to_json
      end

      delete '/:id' do
        begin
          Service.delete_by_id params[:id], force: (params[:force] == 'true')
          {status: :ok}.to_json
        rescue ServiceIsDefaultService => e
          status 400
          {error: e.message}.to_json
        end
      end

      private

      def filter_params(params)
        params.reject!{ |k, v| !ACCEPTED_PARAMS.include? k }
      end
    end
  end
end
