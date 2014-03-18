module ThreeScale
  module Backend
    class ServicesAPI < InternalAPI
      ACCEPTED_PARAMS = %w(id service provider_key)

      before do
        content_type 'application/json'
      end

      get '/:id' do
        Service.load_by_id(params[:id]).to_json
      end

      put '/:id' do
        service = Service.save!(params[:service].merge(id: params[:id]))
        {service: service, status: :ok}.to_json
      end

      get '/list_ids/:provider_key' do
        Service.list(params['provider_key']).to_json
      end

      private

      def filter_params(params)
        params.reject!{ |k, v| !ACCEPTED_PARAMS.include? k }
      end
    end
  end
end
