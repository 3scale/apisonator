require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class ApplicationReferrerFiltersTest < Test::Unit::TestCase
  include TestHelpers::Integration
  include TestHelpers::Sequences
  
  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!

    @provider_key = 'provider_key'
    @service_id   = next_id
    Core::Service.save!(:provider_key => @provider_key, :id => @service_id)

    @application_id = next_id
    Application.save(:service_id => @service_id, 
                     :id         => @application_id,
                     :state      => :active)
  end

  test 'OPTIONS .../referrer_filters.xml returns GET and POST' do
    request "/applications/#{@application_id}/referrer_filters.xml", 
      :method => 'OPTIONS',
      :params => {:provider_key => @provider_key}

    assert_equal 200,         last_response.status
    assert_equal 'GET, POST', last_response.headers['Allow']
  end
  
  test 'OPTIONS .../referrer_filters/{rule}.xml returns DELETE' do
    request "/applications/#{@application_id}/referrer_filters/example.org.xml", 
      :method => 'OPTIONS',
      :params => {:provider_key => @provider_key}

    assert_equal 200,      last_response.status
    assert_equal 'DELETE', last_response.headers['Allow']
  end
  
  test 'GET .../referrer_filters.xml renders list of referrer filters' do
    application = Application.load(@service_id, @application_id)
    application.create_referrer_filter('foo.example.org')
    application.create_referrer_filter('bar.example.org')

    get "/applications/#{@application_id}/referrer_filters.xml", :provider_key => @provider_key

    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    items = doc.at('referrer_filters:root')

    assert_not_nil items
    assert_equal 2, items.search('referrer_filter').count

    item_one = items.at('referrer_filter[value="foo.example.org"]')
    assert_not_nil item_one
    assert_equal "http://example.org/applications/#{@application_id}/referrer_filters/foo.example.org.xml?provider_key=#{@provider_key}", item_one['href']
    
    item_two = items.at('referrer_filter[value="bar.example.org"]')
    assert_not_nil item_two
    assert_equal "http://example.org/applications/#{@application_id}/referrer_filters/bar.example.org.xml?provider_key=#{@provider_key}", item_two['href']
  end
  
  test 'GET .../referrer_filters.xml renders empty list if there are no referrer filters' do
    get "/applications/#{@application_id}/referrer_filters.xml", :provider_key => @provider_key

    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    assert_not_nil doc.at('referrer_filters:root')
    assert_equal 0, doc.search('referrer_filter').count
  end
  
  test 'GET .../referrer_filters.xml fails on invalid provider key' do
    get "/applications/#{@application_id}/referrer_filters.xml", :provider_key => 'boo'
   
    assert_error_response :code    => 'provider_key_invalid',
                          :message => 'provider key "boo" is invalid'
  end

  test 'GET .../referrer_filters.xml fails on invalid application id' do
    get "/applications/boo/referrer_filters.xml", :provider_key => @provider_key

    assert_error_response :status  => 404,
                          :code    => 'application_not_found',
                          :message => 'application with id="boo" was not found'
  end
  
  test 'POST .../referrer_filters.xml creates new referrer filter' do
    url = "http://example.org/applications/#{@application_id}/referrer_filters/example.org.xml?provider_key=#{@provider_key}"

    post "/applications/#{@application_id}/referrer_filters.xml",
      :provider_key => @provider_key,
      :referrer_filter     => 'example.org'

    assert_equal 201, last_response.status
    assert_equal url, last_response.headers['Location']

    doc = Nokogiri::XML(last_response.body)
    assert_equal 'example.org', doc.at('referrer_filter:root')['value']
    assert_equal url,           doc.at('referrer_filter:root')['href']

    application = Application.load(@service_id, @application_id)
    assert application.has_referrer_filter?('example.org')
  end

  test 'POST .../referrer_filters.xml responds with error when blank value is passed' do
    post "/applications/#{@application_id}/referrer_filters.xml",
      :provider_key    => @provider_key,
      :referrer_filter => ''

    assert_error_response :status  => 422,
                          :code    => "referrer_filter_invalid",
                          :message => "referrer filter can't be blank"
  end
  
  test 'POST .../referrer_filters.xml fails on invalid provider key' do
    post "/applications/#{@application_id}/referrer_filters.xml", :provider_key => 'boo'

    assert_error_response :code    => 'provider_key_invalid',
                          :message => 'provider key "boo" is invalid'
  end
  
  test 'POST .../referrer_filters.xml fails on invalid application id' do
    post "/applications/invalid/referrer_filters.xml", :provider_key => @provider_key

    assert_error_response :status  => 404,
                          :code    => 'application_not_found',
                          :message => 'application with id="invalid" was not found'
  end
  
  test 'DELETE .../referrer_filters/{rule}.xml deletes the referrer filter' do
    application = Application.load(@service_id, @application_id)
    application.create_referrer_filter('example.org')

    delete "/applications/#{@application_id}/referrer_filters/example.org.xml",
           :provider_key => @provider_key

    assert_equal 200, last_response.status
    assert !application.has_referrer_filter?('example.org')
  end

  test 'DELETE .../referrer_filters/{rule}.xml succeeds if the referrer filter does not exist' do
    delete "/applications/#{@application_id}/referrer_filters/boo.example.org.xml", 
           :provider_key => @provider_key

    assert_equal 200, last_response.status
  end
  
  test 'DELETE .../referrer_filters/{rule}.xml fails on invalid provider key' do
    application = Application.load(@service_id, @application_id)
    application.create_referrer_filter('example.org')

    delete "/applications/#{@application_id}/referrer_filters/example.org.xml", 
           :provider_key => 'boo'

    assert_error_response :code    => 'provider_key_invalid',
                          :message => 'provider key "boo" is invalid'
  end
  
  test 'DELETE .../referrer_filters/{rule}.xml fails on invalid application id' do
    application = Application.load(@service_id, @application_id)
    application.create_referrer_filter('example.org')

    delete "/applications/boo/referrer_filters/example.org.xml", 
           :provider_key => @provider_key

    assert_error_response :status  => 404,
                          :code    => 'application_not_found',
                          :message => 'application with id="boo" was not found'
  end
end
