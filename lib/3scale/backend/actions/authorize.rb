module ThreeScale
  module Backend
    module Actions
      class Authorize < Action
        def perform(request)
          status = Transactor.authorize(request.params['provider_key'],
                                        request.params['app_id'],
                                        request.params['app_key'])
          
          [200, {'Content-Type' => content_type(request)}, [status.to_xml]]

        rescue Error => exception
          [403, {'Content-Type' => content_type(request)}, [exception.to_xml]]
        end
      end
    end
  end
end
