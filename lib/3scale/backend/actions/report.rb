module ThreeScale
  module Backend
    module Actions
      class Report < Action
        def perform(request)
          Transactor.report(request.params['provider_key'],
                            request.params['transactions'])

          [200, {}, []]
        end
      end
    end
  end
end
