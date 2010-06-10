require File.dirname(__FILE__) + '/../../test_helper'

module V1_0
  class AuthorizeTest < Test::Unit::TestCase
    include TestHelpers::Integration
    include TestHelpers::MasterService
    include TestHelpers::StorageKeys
    
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

      @metric_id = next_id
      Metric.save(:service_id => @service_id, :id => @metric_id, :name => 'hits')
    end

    def test_1_0_is_the_default_version
      get '/transactions/authorize.xml', :provider_key => @provider_key, :user_key => @user_key
      assert_equal '1.0', last_request.api_version
    end

    def test_successful_authorize_responds_with_200
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :user_key     => @user_key,
                                         :version      => '1.0'
      assert_equal 200, last_response.status
    end

    def test_response_of_successful_authorize_contains_plan_name
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :user_key     => @user_key,
                                         :version      => '1.0'

      assert_equal 'application/xml', last_response.content_type

      doc = Nokogiri::XML(last_response.body)
      assert_equal @plan_name, doc.at('status:root plan').content
    end
    
    def test_response_of_successful_authorize_contains_usages_if_the_plan_has_usage_limits
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :day => 100, :month => 10000)

      Timecop.freeze(Time.utc(2010, 5, 14)) do
        Transactor.report(@provider_key,
                          0 => {'user_key' => @user_key, 'usage' => {'hits' => 3}})
      end

      Timecop.freeze(Time.utc(2010, 5, 15)) do
        Transactor.report(@provider_key,
                          0 => {'user_key' => @user_key, 'usage' => {'hits' => 2}})

        get '/transactions/authorize.xml', :provider_key => @provider_key,
                                           :user_key     => @user_key,
                                           :version      => '1.0'
        assert_equal 200, last_response.status

        doc = Nokogiri::XML(last_response.body)
        
        day = doc.at('status:root usage[metric = "hits"][period = "day"]')
        assert_not_nil day
        assert_equal '2010-05-15 00:00:00', day.at('period_start').content
        assert_equal '2010-05-16 00:00:00', day.at('period_end').content
        assert_equal '2',                   day.at('current_value').content
        assert_equal '100',                 day.at('max_value').content
        
        month = doc.at('status:root usage[metric = "hits"][period = "month"]')
        assert_not_nil month
        assert_equal '2010-05-01 00:00:00', month.at('period_start').content
        assert_equal '2010-06-01 00:00:00', month.at('period_end').content
        assert_equal '5',                   month.at('current_value').content
        assert_equal '10000',               month.at('max_value').content
      end
    end
    
    def test_response_of_successful_authorize_does_not_contain_usages_if_the_plan_has_no_usage_limits
      Timecop.freeze(Time.utc(2010, 5, 15)) do
        Transactor.report(@provider_key,
                          0 => {'user_key' => @user_key, 'usage' => {'hits' => 2}})

        get '/transactions/authorize.xml', :provider_key => @provider_key,
                                           :user_key     => @user_key,
                                           :version      => '1.1'

        doc = Nokogiri::XML(last_response.body)
        
        assert_equal 0, doc.search('usage').count
      end
    end
    
    def test_authorize_fails_on_invalid_provider_key
      get '/transactions/authorize.xml', :provider_key => 'boo',
                                         :user_key     => @user_key,
                                         :version      => '1.0'

      assert_equal 'application/xml', last_response.content_type
      
      doc = Nokogiri::XML(last_response.body)

      assert_equal 1, doc.search('errors:root error').count
      node = doc.at('errors:root error')

      assert_not_nil node
      assert_equal 'provider.invalid_key', node['code']
      assert_equal 'provider authentication key is invalid', node.content
    end

    def test_authorize_fails_on_invalid_user_key
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :user_key     => 'boo',
                                         :version      => '1.0'

      assert_equal 'application/xml', last_response.content_type
      
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

      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :user_key     => @user_key,
                                         :version      => '1.0'

      assert_equal 'application/xml', last_response.content_type
      
      doc = Nokogiri::XML(last_response.body)
      node = doc.at('errors:root error')

      assert_not_nil node
      assert_equal 'user.inactive_contract', node['code']
      assert_equal 'contract is not active', node.content
    end

    def test_authorize_fails_on_exceeded_usage_limits
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :day => 4)

      Timecop.freeze(Time.utc(2010, 5, 14)) do
        Transactor.report(@provider_key,
                          0 => {'user_key' => @user_key, 'usage' => {'hits' => 5}})

        get '/transactions/authorize.xml', :provider_key => @provider_key,
                                           :user_key     => @user_key,
                                           :version      => '1.0'

        assert_equal 'application/xml', last_response.content_type

        doc = Nokogiri::XML(last_response.body)
        node = doc.at('errors:root error')

        assert_not_nil node
        assert_equal 'user.exceeded_limits', node['code']
        assert_equal 'usage limits are exceeded', node.content
      end
    end
    
    def test_successful_authorize_reports_backend_hit
      Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
        get '/transactions/authorize.xml', :provider_key => @provider_key,
                                           :user_key     => @user_key,
                                           :version      => '1.0'

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
        get '/transactions/authorize.xml', :provider_key => 'boo',
                                           :user_key     => @user_key,
                                           :version      => '1.0'

        assert_equal 0, @storage.get(contract_key(@master_service_id,
                                                  @master_contract_id,
                                                  @master_authorizes_id,
                                                  :month, '20100501')).to_i
      end
    end
    
    def test_authorize_with_invalid_user_key_reports_backend_hit
      Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
        get '/transactions/authorize.xml', :provider_key => @provider_key,
                                           :user_key     => 'baa',
                                           :version      => '1.0'

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
        get '/transactions/authorize.xml', :provider_key => @provider_key,
                                           :user_key     => @user_key,
                                           :version      => '1.0'

        assert_equal 1, @storage.get(contract_key(@master_service_id,
                                                  @master_contract_id,
                                                  @master_authorizes_id,
                                                  :month, '20100501')).to_i
      end
    end
    
    def test_authorize_with_exceeded_usage_limits_reports_backend_hit
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :day => 4)

      Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
        Transactor.report(@provider_key,
                          0 => {'user_key' => @user_key, 'usage' => {'hits' => 5}})

        get '/transactions/authorize.xml', :provider_key => @provider_key,
                                           :user_key     => @user_key,
                                           :version      => '1.0'

        assert_equal 1, @storage.get(contract_key(@master_service_id,
                                                  @master_contract_id,
                                                  @master_authorizes_id,
                                                  :month, '20100501')).to_i
      end
    end
  end
end
