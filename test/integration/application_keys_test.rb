require File.dirname(__FILE__) + '/../test_helper'

class ApplicationKeysTest < Test::Unit::TestCase
  include TestHelpers::Integration
  include TestHelpers::MasterService
  
  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!

    setup_master_service

    @master_plan_id = next_id
    @provider_key = 'provider_key'
    Application.save(:service_id => @master_service_id, 
                     :id => @provider_key, 
                     :state => :active,
                     :plan_id => @master_plan_id)

    @service_id = next_id
    Core::Service.save(:provider_key => @provider_key, :id => @service_id)

    @application_id = next_id
    @plan_id = next_id
    @plan_name = 'kickass'
    Application.save(:service_id => @service_id, 
                     :id         => @application_id,
                     :state      => :active, 
                     :plan_id    => @plan_id, 
                     :plan_name  => @plan_name)
  end

  def test_options_request_returns_list_of_allowed_methods
    request "/applications/#{@application_id}/keys.xml", 
      :method => 'OPTIONS',
      :params => {:provider_key => @provider_key}

    assert_equal 200,         last_response.status
    assert_equal 'GET, POST', last_response.headers['Allow']
    
    request "/applications/#{@application_id}/keys/foo.xml", 
      :method => 'OPTIONS',
      :params => {:provider_key => @provider_key}

    assert_equal 200,      last_response.status
    assert_equal 'DELETE', last_response.headers['Allow']
  end

  def test_index_renders_list_of_application_keys
    application = Application.load(@service_id, @application_id)
    application.create_key!('foo')
    application.create_key!('bar')

    get "/applications/#{@application_id}/keys.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    keys_node = doc.at('keys:root')

    assert_not_nil keys_node    
    assert_equal 2,     keys_node.search('key').count

    key_one_node = keys_node.at('key[value=foo]')
    assert_not_nil key_one_node
    assert_equal "http://example.org/applications/#{@application_id}/keys/foo.xml?provider_key=#{@provider_key}", key_one_node['href']
    
    key_two_node = keys_node.at('key[value=bar]')
    assert_not_nil key_two_node
    assert_equal "http://example.org/applications/#{@application_id}/keys/bar.xml?provider_key=#{@provider_key}", key_two_node['href']
  end

  def test_index_renders_empty_list_if_there_are_no_application_keys
    get "/applications/#{@application_id}/keys.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    assert_not_nil    doc.at('keys:root')
    assert_equal   0, doc.search('key').count
  end

  def test_index_fails_on_invalid_provider_key
    get "/applications/#{@application_id}/keys.xml", :provider_key => 'boo'
   
    assert_error_response :code    => 'provider_key_invalid',
                          :message => 'provider key "boo" is invalid'
  end

  def test_index_fails_on_invalid_application_id
    get "/applications/boo/keys.xml", :provider_key => @provider_key

    assert_error_response :status  => 404,
                          :code    => 'application_not_found',
                          :message => 'application with id="boo" was not found'
  end

  def test_create_creates_new_random_key
    SecureRandom.stubs(:hex).returns('foo')
    
    url = "http://example.org/applications/#{@application_id}/keys/foo.xml?provider_key=#{@provider_key}"

    post "/applications/#{@application_id}/keys.xml", :provider_key => @provider_key

    assert_equal 201, last_response.status
    assert_equal url, last_response.headers['Location']

    doc = Nokogiri::XML(last_response.body)
    assert_equal 'foo', doc.at('key:root')['value']
    assert_equal url,   doc.at('key:root')['href']

    application = Application.load(@service_id, @application_id)
    assert application.has_key?('foo')
  end

  def test_create_fails_on_invalid_provider_key
    post "/applications/#{@application_id}/keys.xml", :provider_key => 'boo'

    assert_error_response :code    => 'provider_key_invalid',
                          :message => 'provider key "boo" is invalid'
  end
  
  def test_create_fails_on_invalid_application_id
    post "/applications/invalid/keys.xml", :provider_key => @provider_key

    assert_error_response :status  => 404,
                          :code    => 'application_not_found',
                          :message => 'application with id="invalid" was not found'
  end

  def test_delete_deletes_the_key
    application = Application.load(@service_id, @application_id)
    application_key = application.create_key!

    delete "/applications/#{@application_id}/keys/#{application_key}.xml",
           :provider_key => @provider_key

    assert_equal 200, last_response.status
    assert !application.has_key?(application_key)
  end
  
  def test_delete_fails_on_invalid_provider_key
    application = Application.load(@service_id, @application_id)
    application_key = application.create_key!

    delete "/applications/#{@application_id}/keys/#{application_key}.xml", 
           :provider_key => 'boo'

    assert_error_response :code    => 'provider_key_invalid',
                          :message => 'provider key "boo" is invalid'
  end
  
  def test_delete_fails_on_invalid_application_id
    application = Application.load(@service_id, @application_id)
    application_key = application.create_key!

    delete "/applications/boo/keys/#{application_key}.xml", 
           :provider_key => @provider_key

    assert_error_response :status  => 404,
                          :code    => 'application_not_found',
                          :message => 'application with id="boo" was not found'
  end

  def test_delete_fails_on_invalid_key
    delete "/applications/#{@application_id}/keys/boo.xml", 
           :provider_key => @provider_key

    assert_error_response :status  => 404,
                          :code    => 'application_key_not_found',
                          :message => 'application key "boo" was not found'
  end
end
