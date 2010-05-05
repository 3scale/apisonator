require '3scale/backend/action'
require '3scale/backend/transactor'

module ThreeScale
  module Backend
    module Actions
      class Report < Action
        def perform(request)
          Transactor.report(:provider_key => request.params['provider_key'],
                            :transactions => request.params['transactions'])

          [200, {}, []]
        end
      end
    end
  end
end
