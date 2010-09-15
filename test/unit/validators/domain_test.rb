require File.dirname(__FILE__) + '/../../test_helper'

module Validators
  class DomainTest < Test::Unit::TestCase
    include TestHelpers::Sequences
    include Validators

    def setup
      Storage.instance(true).flushdb

      service_id     = next_id
      application_id = next_id

      @application = Application.save(:service_id => service_id,
                                      :id         => application_id,
                                      :state => :active)

      @status = Transactor::Status.new(@application, {})
    end

    test 'succeeds if no domain constraint is defined and no domain is passed' do
      assert Domain.apply(@status, {})
    end
  
    test 'succeeds if no domain constraint is defined and blank one is passed' do
      assert Domain.apply(@status, :domain => '')
    end
    
    test 'succeeds if simple domain constraint is defined and matching domain is passed' do
      @application.create_domain_constraint('example.org')
      assert Domain.apply(@status, :domain => 'example.org')
    end

    # test 'succeeds if multiple application keys are defined and one of them is passed' do
    #   application_key_one = @application.create_key
    #   application_key_two = @application.create_key

    #   assert Key.apply(@status, :app_key => application_key_one)
    #   assert Key.apply(@status, :app_key => application_key_two)
    # end

    test 'fails if domain constraint is defined but no domain is passed' do
      @application.create_domain_constraint('example.org')

      assert !Domain.apply(@status, {})

      assert_equal 'domain_invalid',    @status.rejection_reason_code
      assert_equal 'domain is missing', @status.rejection_reason_text
    end
    # 
    # test 'fails if invalid application key is passed' do
    #   @application.create_key('foo')
    #   
    #   assert !Key.apply(@status, :app_key => 'bar')

    #   assert_equal 'application_key_invalid',          @status.rejection_reason_code
    #   assert_equal 'application key "bar" is invalid', @status.rejection_reason_text
    # end
  end
end
