module TestHelpers
  # Support for integration tests.
  module Integration
    def self.included(base)
      base.class_eval do
        include Rack::Test::Methods
        include TestHelpers::EventMachine
      end
    end
  
    def app
      ThreeScale::Backend::Router
    end
  end
end
