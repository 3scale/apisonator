module ThreeScale
  module Backend
    module Actions
      class Authorize < Action
        def perform(request)
          status = Transactor.authorize(request.params['provider_key'],
                                        request.params['user_key'])

          [200, {'Content-Type' => 'application/xml'}, [status.to_xml]]
        rescue Error => exception
          [403, {'Content-Type' => 'application/xml'}, [exception.to_xml]]
        end
      end
    end
  end
end
