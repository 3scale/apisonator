require File.dirname(__FILE__) + '/../test_helper'

class AuthorizeTest < Test::Unit::TestCase
  include TestHelpers::Integration
  include TestHelpers::MasterService
  include TestHelpers::StorageKeys

  def setup
    @storage = ThreeScale::Backend.storage
    @storage.flushdb

    setup_master_service

    @master_contract_id = next_id
    @provider_key = 'provider_key'
    Contract.save(:service_id => @master_service_id, :user_key => @provider_key,
                  :id => @master_contract_id, :state => :live)

    @service_id = next_id
    Service.save(:provider_key => @provider_key, :id => @service_id)

    @contract_id = next_id
    @user_key = 'user_key'
    @plan_name = 'kickass'
    Contract.save(:service_id => @service_id, :user_key => @user_key, :id => @contract_id,
                  :state => :live, :plan_name => @plan_name)

    # @metric_id = next_id
    # Metrics.save(:service_id => @service_id, @metric_id => {:name => 'hits'})
  end

  def test_successful_report_responds_with_200
    get '/transactions/authorize.xml', :provider_key => @provider_key, :user_key => @user_key
    assert_equal 200, last_response.status
  end

  def test_response_of_successful_report_contains_plan_name
    get '/transactions/authorize.xml', :provider_key => @provider_key, :user_key => @user_key

    assert_equal 'application/xml', last_response.headers['Content-Type']

    doc = Nokogiri::XML(last_response.body)
    assert_equal @plan_name, doc.at('status:root plan').content
  end
  
  def test_authorize_fails_on_invalid_provider_key
    get '/transactions/authorize.xml', :provider_key => 'boo', :user_key => @user_key

    assert_equal 'application/xml', last_response.headers['Content-Type']
    
    doc = Nokogiri::XML(last_response.body)

    assert_equal 1, doc.search('errors:root error').count
    node = doc.at('errors:root error')

    assert_not_nil node
    assert_equal 'provider.invalid_key', node['code']
    assert_equal 'provider authentication key is invalid', node.content
  end

  def test_authorize_fails_on_invalid_user_key
    get '/transactions/authorize.xml', :provider_key => @provider_key, :user_key => 'boo'

    assert_equal 'application/xml', last_response.headers['Content-Type']
    
    doc = Nokogiri::XML(last_response.body)
    node = doc.at('errors:root error')

    assert_not_nil node
    assert_equal 'user.invalid_key', node['code']
    assert_equal 'user_key is invalid', node.content
  end
  
  def test_authorize_fails_on_inactive_contract
    contract = Contract.load(@service_id, @user_key)
    contract.state = :suspended
    contract.save

    get '/transactions/authorize.xml', :provider_key => @provider_key, :user_key => @user_key

    assert_equal 'application/xml', last_response.headers['Content-Type']
    
    doc = Nokogiri::XML(last_response.body)
    node = doc.at('errors:root error')

    assert_not_nil node
    assert_equal 'user.inactive_contract', node['code']
    assert_equal 'contract is not active', node.content
  end
  
  def test_successful_authorize_reports_backend_hit
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      get '/transactions/authorize.xml', :provider_key => @provider_key, :user_key => @user_key

      assert_equal 1, @storage.get(contract_key(@master_service_id,
                                                @master_contract_id,
                                                @master_hits_id,
                                                :month, '20100501')).to_i

      assert_equal 1, @storage.get(contract_key(@master_service_id,
                                                @master_contract_id,
                                                @master_authorizes_id,
                                                :month, '20100501')).to_i
    end
  end
  
  def test_authorize_with_invalid_provider_key_does_not_report_backend_hit
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      get '/transactions/authorize.xml', :provider_key => 'boo', :user_key => @user_key

      assert_equal 0, @storage.get(contract_key(@master_service_id,
                                                @master_contract_id,
                                                @master_authorizes_id,
                                                :month, '20100501')).to_i
    end
  end
  
  def test_authorize_with_invalid_user_key_reports_backend_hit
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      get '/transactions/authorize.xml', :provider_key => @provider_key, :user_key => 'baa'

      assert_equal 1, @storage.get(contract_key(@master_service_id,
                                                @master_contract_id,
                                                @master_authorizes_id,
                                                :month, '20100501')).to_i
    end
  end
  
  def test_authorize_with_inactive_contract_reports_backend_hit
    contract = Contract.load(@service_id, @user_key)
    contract.state = :suspended
    contract.save

    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      get '/transactions/authorize.xml', :provider_key => @provider_key, :user_key => @user_key

      assert_equal 1, @storage.get(contract_key(@master_service_id,
                                                @master_contract_id,
                                                @master_authorizes_id,
                                                :month, '20100501')).to_i
    end
  end
end
