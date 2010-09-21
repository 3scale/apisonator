require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Validators
  class KeyTest < Test::Unit::TestCase
    include TestHelpers::Sequences
    include Validators

    def setup
      Storage.instance(true).flushdb

      @application = Application.save(:service_id => next_id,
                                      :id         => next_id,
                                      :state => :active)

      @status = Transactor::Status.new(nil, @application, {})
    end

    test 'succeeds if no application key is defined nor passed' do
      assert Key.apply(@status, {})
    end
  
    test 'succeeds if no application key is defined and blank one is passed' do
      assert Key.apply(@status, :app_key => '')
    end

    test 'succeeds if one application key is defined and the same is passed' do
      application_key = @application.create_key
      assert Key.apply(@status, :app_key => application_key)
    end

    test 'succeeds if multiple application keys are defined and one of them is passed' do
      application_key_one = @application.create_key
      application_key_two = @application.create_key

      assert Key.apply(@status, :app_key => application_key_one)
      assert Key.apply(@status, :app_key => application_key_two)
    end

    test 'fails if application key is defined but not passed' do
      @application.create_key
      
      assert !Key.apply(@status, {})

      assert_equal 'application_key_invalid',    @status.rejection_reason_code
      assert_equal 'application key is missing', @status.rejection_reason_text
    end
    
    test 'fails if invalid application key is passed' do
      @application.create_key('foo')
      
      assert !Key.apply(@status, :app_key => 'bar')

      assert_equal 'application_key_invalid',          @status.rejection_reason_code
      assert_equal 'application key "bar" is invalid', @status.rejection_reason_text
    end
  end
end
