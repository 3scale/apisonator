module TestHelpers
  module Errors
    include ThreeScale
    include ThreeScale::Backend

    def self.included(base)
      base.send(:include, TestHelpers::Sequences)
    end

    private

    def assert_not_errors_in_transactions(service_ids)
      service_ids.each { |id| assert_equal(0, ErrorStorage.count(id)) }
    end

    def assert_error_in_transactions(service_id, code, message)
      error = ErrorStorage.list(service_id).first # There will only be one
      assert_equal code, error[:code]
      assert_equal message, error[:message]
    end
  end
end
