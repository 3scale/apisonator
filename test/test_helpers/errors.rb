module TestHelpers
  module Errors
    include ThreeScale
    include ThreeScale::Backend

    def self.included(base)
      base.send(:include, TestHelpers::Sequences)
    end

    private

    def assert_not_errors_in_transactions
      get "/transactions/errors.xml", provider_key: @provider_key
      assert_equal 200, last_response.status
      doc = Nokogiri::XML(last_response.body)
      assert_not_nil doc.at('errors:root')
      assert_equal 0, doc.search('errors error').size
    end

    def assert_error_in_transactions(service_id, code, message)
      get "/transactions/errors.xml", provider_key: @provider_key, service_id: service_id
      assert_equal 200, last_response.status
      doc  = Nokogiri::XML(last_response.body)
      node = doc.search('errors error').last

      assert_not_nil node
      assert_equal code, node['code']
      assert_equal message, node.content
    end
  end
end
