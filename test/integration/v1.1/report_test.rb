require File.dirname(__FILE__) + '/../../test_helper'

module V1_1
  class ReportTest < Test::Unit::TestCase
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
      Contract.save(:service_id => @service_id, :plan_id => @plan_id, :id => @contract_id,
                    :user_key => @user_key, :state => :live)

      @metric_id = next_id
      Metric.save(:service_id => @service_id, :id => @metric_id, :name => 'hits')
    end
    
    def test_report_fails_on_invalid_provider_key
      post '/transactions.xml',
        {:provider_key => 'boo',
         :transactions => {0 => {:user_key => @user_key, :usage => {'hits' => 1}}}},
        'HTTP_ACCEPT' => 'application/vnd.3scale-v1.1+xml'

      assert_equal 'application/vnd.3scale-v1.1+xml', last_response.content_type
      
      doc = Nokogiri::XML(last_response.body)

      assert_equal 1, doc.search('errors:root error').count
      node = doc.at('errors:root error')

      assert_not_nil node
      assert_equal 'provider.invalid_key', node['code']
      assert_equal 'provider authentication key is invalid', node.content
    end

    def test_report_fails_on_invalid_user_key
      post '/transactions.xml',
        {:provider_key => @provider_key,
         :transactions => {0 => {:user_key => 'boo', :usage => {'hits' => 1}}}},
        'HTTP_ACCEPT' => 'application/vnd.3scale-v1.1+xml'

      assert_equal 'application/vnd.3scale-v1.1+xml', last_response.content_type
      
      doc = Nokogiri::XML(last_response.body)
      node = doc.at('errors:root error[index = "0"]')

      assert_not_nil node
      assert_equal 'user.invalid_key', node['code']
      assert_equal 'user_key is invalid', node.content
    end
    
    def test_report_fails_on_invalid_metric_name
      post '/transactions.xml',
        {:provider_key => @provider_key,
         :transactions => {0 => {:user_key => @user_key, :usage => {'nukes' => 1}}}},
        'HTTP_ACCEPT' => 'application/vnd.3scale-v1.1+xml'

      assert_equal 'application/vnd.3scale-v1.1+xml', last_response.content_type
      
      doc = Nokogiri::XML(last_response.body)
      node = doc.at('errors:root error[index = "0"]')

      assert_not_nil node
      assert_equal 'provider.invalid_metric', node['code']
      assert_equal 'metric does not exist', node.content
    end
    
    def test_report_fails_on_invalid_usage_value
      post '/transactions.xml',
        {:provider_key => @provider_key,
         :transactions => {0 => {:user_key => @user_key, :usage => {'hits' => 'tons!'}}}},
        'HTTP_ACCEPT' => 'application/vnd.3scale-v1.1+xml'

      assert_equal 'application/vnd.3scale-v1.1+xml', last_response.content_type
      
      doc = Nokogiri::XML(last_response.body)
      node = doc.at('errors:root error[index = "0"]')

      assert_not_nil node
      assert_equal 'provider.invalid_usage_value', node['code']
      assert_equal 'usage value is invalid', node.content
    end
  end
end
