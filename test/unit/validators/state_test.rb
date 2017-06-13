require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Validators
  class StateTest < Test::Unit::TestCase
    include TestHelpers::Sequences
    include Validators

    def setup
      Storage.instance(true).flushdb

      service_id = next_id
      @application = Application.save(service_id: service_id,
                                      id: next_id,
                                      state: :active)

      @status = Transactor::Status.new(service_id: service_id,
                                       application: @application)
    end

    test 'succeeds when application is active' do
      @application.state = :active
      @application.save

      assert State.apply(@status, {})
    end

    test 'fails when application is suspended' do
      @application.state = :suspended
      @application.save

      assert !State.apply(@status, {})
      assert_equal 'application_not_active',    @status.rejection_reason_code
      assert_equal 'application is not active', @status.rejection_reason_text
    end
  end
end
