require File.dirname(__FILE__) + '/../../test_helper'

module V1
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

    def test_response_of_successful_authorize_contains_plan_name
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :user_key     => @user_key,
                                         :version      => '1'

      assert_equal 'application/xml', last_response.headers['Content-Type']

      doc = Nokogiri::XML(last_response.body)
      assert_equal @plan_name, doc.at('status:root plan').content
    end
  end
end
