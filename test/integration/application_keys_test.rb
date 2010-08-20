require File.dirname(__FILE__) + '/../test_helper'

# class ApplicationKeysTest < Test::Unit::TestCase
#   include TestHelpers::Integration
#   include TestHelpers::MasterService
#   # include TestHelpers::StorageKeys
#   
#   def setup
#     @storage = Storage.instance(true)
#     @storage.flushdb
# 
#     Resque.reset!
# 
#     setup_master_service
# 
#     @master_plan_id = next_id
#     @provider_key = 'provider_key'
#     Application.save(:service_id => @master_service_id, 
#                      :id => @provider_key, 
#                      :state => :active,
#                      :plan_id => @master_plan_id)
# 
#     @service_id = next_id
#     Core::Service.save(:provider_key => @provider_key, :id => @service_id)
# 
#     @application_id = next_id
#     @plan_id = next_id
#     @plan_name = 'kickass'
#     Application.save(:service_id => @service_id, 
#                      :id         => @application_id,
#                      :state      => :active, 
#                      :plan_id    => @plan_id, 
#                      :plan_name  => @plan_name)
#   end
# 
#   def test_index_fails_on_invalid_provider_key
#     get "/applications/#{@application_id}/keys", :provider_key => 'boo'
#     
#     assert_equal 403,                               last_response.status
#     assert_equal 'application/vnd.3scale-v1.1+xml', last_response.content_type
# 
#     doc = Nokogiri::XML(last_response.body)
# 
#     node = doc.at('error:root')
# 
#     assert_not_nil node
#     assert_equal 'provider_key_invalid',          node['code']
#     assert_equal 'provider key "boo" is invalid', node.content
#   end
# end
