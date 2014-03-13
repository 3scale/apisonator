module ThreeScale
  module Backend
    class ServicesAPI < InternalAPI

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
    end
  end
end
