module ThreeScale
  module Backend
    class ServicesAPI < InternalAPI
      before do
        filter_params
        content_type 'application/json'
      end

      get '/' do
        get_service(params).to_json
      end

      get '/list_ids' do
        Service.list(params['provider_key']).to_json
      end

      private

      def get_service(options)
        if params['provider_key']
          Service.load params['provider_key']
        elsif params['id']
          Service.load_by_id params['id']
        else
          nil
        end
      end

      def filter_params
        params.reject!{ |k, v| !['provider_key', 'id'].include? k }
      end
    end
  end
end
