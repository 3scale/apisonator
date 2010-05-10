module TestHelpers
  # Support for integration tests.
  module Integration
    include Rack::Test::Methods
  
    def app
      ThreeScale::Backend::Application
    end
  end
end
