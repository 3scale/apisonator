require '3scale/backend/action'

module ThreeScale
  module Backend
    module Actions
      class Authorize < Action
        def call(env)
          [200, {}, ['Hello world!']]
        end
      end
    end
  end
end
