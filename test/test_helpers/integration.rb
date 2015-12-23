module TestHelpers
  # Support for integration tests.
  module Integration
    def self.included(base)
      base.class_eval do
        include Rack::Test::Methods
      end
    end

    def app
      ThreeScale::Backend::Listener.new
    end

    private

    def assert_error_response(options = {})
      options = {:status       => 403,
                 :content_type => 'application/vnd.3scale-v2.0+xml'}.merge(options)

      assert_equal options[:status],       last_response.status
      assert_includes last_response.content_type, options[:content_type]

      doc = Nokogiri::XML(last_response.body)
      node = doc.at('error:root')

      assert_not_nil node
      assert_equal options[:code],    node['code'] if options[:code]
      assert_equal options[:message], node.content if options[:message]
    end

    # helpers for assertions about big parameters
    def response_too_big_status(response = last_response)
      response.status == 400 &&
        (err = Nokogiri::XML(response.body).at('error:root')) &&
        err['code'] == 'params_too_big'
    end

    def assert_too_big(response = last_response)
      assert response_too_big_status(response)
    end

    def assert_not_too_big(response = last_response)
      refute response_too_big_status(response)
    end
  end
end
