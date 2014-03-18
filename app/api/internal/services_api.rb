module ThreeScale
  module Backend
    class ServicesAPI < InternalAPI
      before do
        filter_params
        content_type 'application/json'
      end

      get '/:id' do
        Service.load_by_id(params[:id]).to_json
      end

      get '/list_ids/:provider_key' do
        Service.list(params['provider_key']).to_json
      end

      private

      def filter_params
        params.reject!{ |k, v| !['provider_key', 'id'].include? k }
      end
    end
  end
end
