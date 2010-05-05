module TestHelpers
  # Support for integration tests.
  module Integration
    include Rack::Test::Methods
  
    def app
      Application
    end
  end
end
