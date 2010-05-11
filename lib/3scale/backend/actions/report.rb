module ThreeScale
  module Backend
    module Actions
      class Report < Action
        def perform(request)
          Transactor.report(request.params['provider_key'],
                            request.params['transactions'])

          [200, {}, []]
        rescue Error => exception
          [403, {'Content-Type' => 'application/xml'}, [exception.to_xml]]
        end
      end
    end
  end
end
