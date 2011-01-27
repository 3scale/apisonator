module TestHelpers
  module AuthorizeAssertions
    private

    def assert_authorized
      assert_equal 200, last_response.status

      doc = Nokogiri::XML(last_response.body)
      assert_equal 'true', doc.at('status authorized').content
    end

    def assert_not_authorized(reason = nil)
      assert_equal 409, last_response.status

      doc = Nokogiri::XML(last_response.body)
      assert_equal 'false', doc.at('status authorized').content
      assert_equal reason,  doc.at('status reason').content if reason
    end
  end
end
