require '3scale/backend/action'

module ThreeScale
  module Backend
    module Actions
      class Report < Action
        def call(env)
          [200, {}, []]
        end
      end
    end
  end
end
