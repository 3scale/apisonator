module ThreeScale
  module Backend
    class ServicesAPI < InternalAPI
      before do
        content_type 'application/json'
      end

      get '/' do
        service = if params['provider_key']
          Service.load params['provider_key']
        elsif params['id']
          Service.load_by_id params['id']
        else
          nil
        end
        service.to_json
      end

      get '/list_ids' do
        list = Service.list(params['provider_key'])
        list.to_json
      end

    end
  end
end
