require '3scale/backend/configuration'

module ThreeScale
  module Tasks
    module Helpers
      module Environment
        module_function

        def testable?
          !%w(preview production).include?(ENV['RACK_ENV'])
        end

        def saas?
          ThreeScale::Backend.configuration.saas
        end
      end
    end
  end
end
