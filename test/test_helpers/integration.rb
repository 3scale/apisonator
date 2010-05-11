module TestHelpers
  # Support for integration tests.
  module Integration
    def self.included(base)
      base.class_eval do
        include Rack::Test::Methods
        include TestHelpers::EventMachine

        alias_method :last_response_without_async, :last_response
        alias_method :last_response, :last_response_with_async
      end
    end
  
    def app
      ThreeScale::Backend::Application
    end

    def async_request(method, uri, params = {}, env = {}, &block)
      callback = lambda do |status, headers, body|
        @last_async_response = Rack::MockResponse.new(status, headers, body)
        block.call
      end

      send(method, uri, params, env.merge('async.callback' => callback))
    end

    def async_get(uri, params = {}, env = {}, &block)
      async_request(:get, uri, params, env, &block)
    end
    
    def async_post(uri, params = {}, env = {}, &block)
      async_request(:post, uri, params, env, &block)
    end

    def last_response_with_async
      @last_async_response || last_response_without_async
    end
  end
end
