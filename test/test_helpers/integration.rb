module TestHelpers
  # Support for integration tests.
  module Integration
    def self.included(base)
      base.class_eval do
        include Rack::Test::Methods
      end
    end
  
    def app
      Rack::Builder.new do
        use Rack::RestApiVersioning, :default_version => '1.1'
        run ThreeScale::Backend::Router.new
      end
    end
  end
end
