require File.dirname(__FILE__) + '/../test_helper'

class AuthorizeTest < Test::Unit::TestCase
  include TestHelpers::Integration
  include TestHelpers::MasterService
  
  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    setup_master_service

    @master_contract_id = next_id
    @provider_key = 'provider_key'
    Contract.save(:service_id => @master_service_id, :user_key => @provider_key,
                  :id => @master_contract_id, :state => :live)

    @service_id = next_id
    Core::Service.save(:provider_key => @provider_key, :id => @service_id)

    @contract_id = next_id
    @user_key = 'user_key'
    @plan_id = next_id
    @plan_name = 'kickass'
    Contract.save(:service_id => @service_id, :user_key => @user_key, :id => @contract_id,
                  :state => :live, :plan_id => @plan_id, :plan_name => @plan_name)
  end

  def test_on_unsupported_api_version_responds_with_406
    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :user_key     => @user_key,
                                       :version      => '9999'

    assert_equal 406, last_response.status
  end
end
