require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

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

  test 'OPTIONS /applications/{app_id}/keys.xml returns GET and POST' do
    request "/applications/#{@application_id}/keys.xml", 
      :method => 'OPTIONS',
      :params => {:provider_key => @provider_key}

    assert_equal 200,         last_response.status
    assert_equal 'GET, POST', last_response.headers['Allow']
  end

  test 'OPTIONS /applications/{app_id}/keys/{key}.xml returns DELETE' do
    request "/applications/#{@application_id}/keys/foo.xml", 
      :method => 'OPTIONS',
      :params => {:provider_key => @provider_key}

    assert_equal 200,      last_response.status
    assert_equal 'DELETE', last_response.headers['Allow']
  end

  test 'GET /applications/{app_id}/keys.xml renders list of application keys' do
    application = Application.load(@service_id, @application_id)
    application.create_key('foo')
    application.create_key('bar')

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

  test 'GET /applications/{app_id}/keys.xml renders empty list if there are no application keys' do
    get "/applications/#{@application_id}/keys.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    assert_not_nil    doc.at('keys:root')
    assert_equal   0, doc.search('key').count
  end

  test 'GET /applications/{app_id}/keys.xml fails on invalid provider key' do
    get "/applications/#{@application_id}/keys.xml", :provider_key => 'boo'
   
    assert_error_response :code    => 'provider_key_invalid',
                          :message => 'provider key "boo" is invalid'
  end

  test 'GET /applications/{app_id}keys.xml fails on invalid application id' do
    get "/applications/boo/keys.xml", :provider_key => @provider_key

    assert_error_response :status  => 404,
                          :code    => 'application_not_found',
                          :message => 'application with id="boo" was not found'
  end

  test 'POST /applications/{app_id]/keys.xml creates new random key' do
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

  test 'POST /applications/{app_id}/keys.xml fails on invalid provider key' do
    post "/applications/#{@application_id}/keys.xml", :provider_key => 'boo'

    assert_error_response :code    => 'provider_key_invalid',
                          :message => 'provider key "boo" is invalid'
  end
  
  test 'POST /applications/{app_id}/keys.xml fails on invalid application id' do
    post "/applications/invalid/keys.xml", :provider_key => @provider_key

    assert_error_response :status  => 404,
                          :code    => 'application_not_found',
                          :message => 'application with id="invalid" was not found'
  end

  test 'DELETE /applications/{app_id}/keys/{key}.xml deletes the key' do
    application = Application.load(@service_id, @application_id)
    application_key = application.create_key

    delete "/applications/#{@application_id}/keys/#{application_key}.xml",
           :provider_key => @provider_key

    assert_equal 200, last_response.status
    assert !application.has_key?(application_key)
  end
  
  test 'DELETE /applications/{app_id}/keys/{key}.xml fails on invalid provider key' do
    application = Application.load(@service_id, @application_id)
    application_key = application.create_key

    delete "/applications/#{@application_id}/keys/#{application_key}.xml", 
           :provider_key => 'boo'

    assert_error_response :code    => 'provider_key_invalid',
                          :message => 'provider key "boo" is invalid'
  end
  
  test 'DELETE /applications/{app_id}/keys/{key}.xml fails on invalid application id' do
    application = Application.load(@service_id, @application_id)
    application_key = application.create_key

    delete "/applications/boo/keys/#{application_key}.xml", 
           :provider_key => @provider_key

    assert_error_response :status  => 404,
                          :code    => 'application_not_found',
                          :message => 'application with id="boo" was not found'
  end

  test 'DELETE /applications/{app_id}/keys/{key}.xml succeeds if the key does not exist' do
    delete "/applications/#{@application_id}/keys/boo.xml", 
           :provider_key => @provider_key

    assert_equal 200, last_response.status           
  end
end
