require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class ApplicationKeysTest < Test::Unit::TestCase
  include TestHelpers::Integration
  include TestHelpers::Sequences
  
  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!

    @provider_key = 'provider_key'

    @service     = Core::Service.save!(:provider_key => @provider_key, :id => next_id)
    @application = Application.save(:service_id => @service.id, 
                                    :id         => next_id,
                                    :state      => :active)
  end

  test 'OPTIONS .../keys.xml returns GET and POST' do
    request "/applications/#{@application.id}/keys.xml", 
      :method => 'OPTIONS',
      :params => {:provider_key => @provider_key}

    assert_equal 200,         last_response.status
    assert_equal 'GET, POST', last_response.headers['Allow']
  end

  test 'OPTIONS .../keys/{key}.xml returns DELETE' do
    request "/applications/#{@application.id}/keys/foo.xml", 
      :method => 'OPTIONS',
      :params => {:provider_key => @provider_key}

    assert_equal 200,      last_response.status
    assert_equal 'DELETE', last_response.headers['Allow']
  end

  test 'GET .../keys.xml renders list of application keys' do
    @application.create_key('foo')
    @application.create_key('bar')

    get "/applications/#{@application.id}/keys.xml",
      :provider_key => @provider_key

    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    keys_node = doc.at('keys:root')

    assert_not_nil keys_node    
    assert_equal 2,     keys_node.search('key').count

    key_one_node = keys_node.at('key[value=foo]')
    assert_not_nil key_one_node
    assert_equal "http://example.org/applications/#{@application.id}/keys/foo.xml?provider_key=#{@provider_key}", key_one_node['href']
    
    key_two_node = keys_node.at('key[value=bar]')
    assert_not_nil key_two_node
    assert_equal "http://example.org/applications/#{@application.id}/keys/bar.xml?provider_key=#{@provider_key}", key_two_node['href']
  end

  test 'GET .../keys.xml renders empty list if there are no application keys' do
    get "/applications/#{@application.id}/keys.xml",
      :provider_key => @provider_key

    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    assert_not_nil    doc.at('keys:root')
    assert_equal   0, doc.search('key').count
  end

  test 'GET .../keys.xml fails on invalid provider key' do
    get "/applications/#{@application.id}/keys.xml", :provider_key => 'boo'
   
    assert_error_response :code    => 'provider_key_invalid',
                          :message => 'provider key "boo" is invalid'
  end

  test 'GET .../keys.xml fails on invalid application id' do
    get "/applications/boo/keys.xml", :provider_key => @provider_key

    assert_error_response :status  => 404,
                          :code    => 'application_not_found',
                          :message => 'application with id="boo" was not found'
  end

  test 'POST .../keys.xml creates new random key' do
    SecureRandom.stubs(:hex).returns('foo')
    
    url = "http://example.org/applications/#{@application.id}/keys/foo.xml?provider_key=#{@provider_key}"

    post "/applications/#{@application.id}/keys.xml",
      :provider_key => @provider_key

    assert_equal 201, last_response.status
    assert_equal url, last_response.headers['Location']

    doc = Nokogiri::XML(last_response.body)
    assert_equal 'foo', doc.at('key:root')['value']
    assert_equal url,   doc.at('key:root')['href']

    assert @application.has_key?('foo')
  end


  test 'POST .../keys.xml creates a custom key' do
    #SecureRandom.stubs(:hex).returns('foo')
    
    @custom_key = 'custom_key_1'
    url = "http://example.org/applications/#{@application.id}/keys/#{@custom_key}.xml?provider_key=#{@provider_key}"

    post "/applications/#{@application.id}/keys.xml",
      :provider_key => @provider_key,
      :key => @custom_key

    assert_equal 201, last_response.status
    assert_equal url, last_response.headers['Location']

    doc = Nokogiri::XML(last_response.body)
    assert_equal @custom_key, doc.at('key:root')['value']
    assert_equal url,   doc.at('key:root')['href']

    assert_equal [@custom_key], @application.keys

    assert @application.has_key?(@custom_key)
    

  end

  


  test 'POST .../keys.xml fails on invalid provider key' do
    post "/applications/#{@application.id}/keys.xml", :provider_key => 'boo'

    assert_error_response :code    => 'provider_key_invalid',
                          :message => 'provider key "boo" is invalid'
  end
  
  test 'POST .../keys.xml fails on invalid application id' do
    post "/applications/invalid/keys.xml", :provider_key => @provider_key

    assert_error_response :status  => 404,
                          :code    => 'application_not_found',
                          :message => 'application with id="invalid" was not found'
  end

  test 'DELETE .../keys/{key}.xml deletes the key' do
    application_key = @application.create_key

    delete "/applications/#{@application.id}/keys/#{application_key}.xml",
           :provider_key => @provider_key

    assert_equal 200, last_response.status
    assert !@application.has_key?(application_key)
  end
  
  test 'DELETE .../keys/{key}.xml fails on invalid provider key' do
    application_key = @application.create_key

    delete "/applications/#{@application.id}/keys/#{application_key}.xml", 
           :provider_key => 'boo'

    assert_error_response :code    => 'provider_key_invalid',
                          :message => 'provider key "boo" is invalid'
  end
  
  test 'DELETE .../keys/{key}.xml fails on invalid application id' do
    application_key = @application.create_key

    delete "/applications/boo/keys/#{application_key}.xml", 
           :provider_key => @provider_key

    assert_error_response :status  => 404,
                          :code    => 'application_not_found',
                          :message => 'application with id="boo" was not found'
  end

  test 'DELETE .../keys/{key}.xml succeeds if the key does not exist' do
    delete "/applications/#{@application.id}/keys/boo.xml", 
           :provider_key => @provider_key

    assert_equal 200, last_response.status           
  end
end
