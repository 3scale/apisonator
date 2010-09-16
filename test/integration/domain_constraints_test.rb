require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class DomainConstraintsTest < Test::Unit::TestCase
  include TestHelpers::Integration
  include TestHelpers::Sequences
  
  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!

    @provider_key = 'provider_key'
    @service_id   = next_id
    Core::Service.save(:provider_key => @provider_key, :id => @service_id)

    @application_id = next_id
    Application.save(:service_id => @service_id, 
                     :id         => @application_id,
                     :state      => :active)
  end

  test 'OPTIONS .../constraints/domains.xml returns GET and POST' do
    request "/applications/#{@application_id}/constraints/domains.xml", 
      :method => 'OPTIONS',
      :params => {:provider_key => @provider_key}

    assert_equal 200,         last_response.status
    assert_equal 'GET, POST', last_response.headers['Allow']
  end
  
  test 'GET .../constraints/domains.xml renders list of domain constraints' do
    application = Application.load(@service_id, @application_id)
    application.create_domain_constraint('foo.example.org')
    application.create_domain_constraint('bar.example.org')

    get "/applications/#{@application_id}/constraints/domains.xml", 
      :provider_key => @provider_key

    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    items = doc.at('domain_constraints:root')

    assert_not_nil items
    assert_equal 2, items.search('domain_constraint').count

    item_one = items.at('domain_constraint[value="foo.example.org"]')
    assert_not_nil item_one
    assert_equal "http://example.org/applications/#{@application_id}/constraints/domains/foo.example.org.xml?provider_key=#{@provider_key}", item_one['href']
    
    item_two = items.at('domain_constraint[value="bar.example.org"]')
    assert_not_nil item_two
    assert_equal "http://example.org/applications/#{@application_id}/constraints/domains/bar.example.org.xml?provider_key=#{@provider_key}", item_two['href']
  end
  
  test 'GET .../constraints/domains.xml renders empty list if there are no domain constraints' do
    get "/applications/#{@application_id}/constraints/domains.xml",
      :provider_key => @provider_key

    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    assert_not_nil    doc.at('domain_constraints:root')
    assert_equal   0, doc.search('domain_constraint').count
  end
  
  test 'GET .../constraints/domains.xml fails on invalid provider key' do
    get "/applications/#{@application_id}/constraints/domains.xml", :provider_key => 'boo'
   
    assert_error_response :code    => 'provider_key_invalid',
                          :message => 'provider key "boo" is invalid'
  end

  test 'GET .../constraints/domains.xml fails on invalid application id' do
    get "/applications/boo/constraints/domains.xml", :provider_key => @provider_key

    assert_error_response :status  => 404,
                          :code    => 'application_not_found',
                          :message => 'application with id="boo" was not found'
  end
  
  test 'POST .../constraints/domains.xml creates new domain constraint' do
    url = "http://example.org/applications/#{@application_id}/constraints/domains/example.org.xml?provider_key=#{@provider_key}"

    post "/applications/#{@application_id}/constraints/domains.xml",
      :provider_key      => @provider_key,
      :domain_constraint => 'example.org'

    assert_equal 201, last_response.status
    assert_equal url, last_response.headers['Location']

    doc = Nokogiri::XML(last_response.body)
    assert_equal 'example.org', doc.at('domain_constraint:root')['value']
    assert_equal url,           doc.at('domain_constraint:root')['href']

    application = Application.load(@service_id, @application_id)
    assert application.has_domain_constraint?('example.org')
  end
end
