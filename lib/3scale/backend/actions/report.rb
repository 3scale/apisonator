require '3scale/backend/action'
require '3scale/backend/transactor'

module ThreeScale
  module Backend
    module Actions
      class Report < Action
        def perform(request)
          Transactor.report(Account.id_by_api_key(request.params['provider_key']),
                            request.params['transactions'])

          [200, {}, []]
        end
      end
    end
  end
end
