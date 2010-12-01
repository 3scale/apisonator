require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class TransactionErrorsTest < Test::Unit::TestCase
  include TestHelpers::Fixtures
  include TestHelpers::Integration

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!

    setup_provider_fixtures
  end

  test 'OPTION /transactions/errors.xml returns GET and DELETE' do
    request "/transactions/errors.xml",
      :method => 'OPTIONS',
      :params => {:provider_key => @provider_key}

    assert_equal 200,           last_response.status
    assert_equal 'GET, DELETE', last_response.headers['Allow']
  end

  test 'GET /transactions/errors.xml contains no items if there are no errors' do
    get "/transactions/errors.xml", :provider_key => @provider_key

    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    assert_not_nil doc.at('errors:root')
    assert_equal 0, doc.search('errors error').size
  end

  test 'GET /transactions/errors.xml contains list of errors' do
    # Let's make some errors first:
    Timecop.freeze(Time.utc(2010, 9, 3, 17, 9)) do
      ErrorStorage.store(@service_id, ApplicationNotFound.new('boo'))
    end

    get "/transactions/errors.xml", :provider_key => @provider_key

    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    node = doc.search('errors error').first

    assert_not_nil node
    assert_equal 'application_not_found',   node['code']
    assert_equal '2010-09-03 17:09:00 UTC', node['timestamp']
    assert_equal 'application with id="boo" was not found', node.content
  end

  test 'GET /transactions/errors.xml supports pagination' do
    2.times { ErrorStorage.store(@service_id, MetricInvalid.new('foo')) }
    3.times { ErrorStorage.store(@service_id, UsageValueInvalid.new('hits', 'lots')) }
    3.times { ErrorStorage.store(@service_id, ApplicationNotFound.new('boo')) }

    # First page
    get "/transactions/errors.xml", :provider_key => @provider_key, :page => 1, :per_page => 3
    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    assert_equal 3, doc.search('error').size
    assert_equal 'application_not_found', doc.search('error').first['code']


    # Second page
    get "/transactions/errors.xml", :provider_key => @provider_key, :page => 2, :per_page => 3
    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    assert_equal 3, doc.search('error').size
    assert_equal 'usage_value_invalid', doc.search('error').first['code']


    # Third page
    get "/transactions/errors.xml", :provider_key => @provider_key, :page => 3, :per_page => 3
    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    assert_equal 2, doc.search('error').size
    assert_equal 'metric_invalid', doc.search('error').first['code']
  end

  test 'GET /transactions/errors.xml shows 100 errors per page by default' do
    110.times { ErrorStorage.store(@service_id, MetricInvalid.new('foo')) }

    get "/transactions/errors.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    assert_equal 100, Nokogiri::XML(last_response.body).search('error').size
  end

  test 'GET /transactions/errors.xml fails on invalid provider key' do
    get "/transactions/errors.xml", :provider_key => 'boo'

    assert_error_response :code    => 'provider_key_invalid',
                          :message => 'provider key "boo" is invalid'
  end

  test 'OPTION /transactions/errors/count.xml returns GET' do
    request "/transactions/errors/count.xml",
      :method => 'OPTIONS',
      :params => {:provider_key => @provider_key}

    assert_equal 200,   last_response.status
    assert_equal 'GET', last_response.headers['Allow']
  end

  test 'GET /transactions/errors/count.xml returns number of stored errors' do
    5.times { ErrorStorage.store(@service_id, MetricInvalid.new('foo')) }

    get "/transactions/errors/count.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    assert_equal '5', doc.at('count').content
  end

  test 'GET /transactions/errors/count.xml fails on invalid provider key' do
    get "/transactions/errors/count.xml", :provider_key => 'boo'

    assert_error_response :code    => 'provider_key_invalid',
                          :message => 'provider key "boo" is invalid'
  end

  test 'DELETE /transactions/errors.xml deletes all errors' do
    ErrorStorage.store(@service_id, ApplicationNotFound.new('boo'))

    delete "/transactions/errors.xml", :provider_key => @provider_key

    assert_equal 200, last_response.status
    assert_equal [], ErrorStorage.list(@service_id)
  end

  test 'DELETE /transactions/errors.xml fails on invalid provider key' do
    delete "/transactions/errors.xml", :provider_key => 'boo'

    assert_error_response :code    => 'provider_key_invalid',
                          :message => 'provider key "boo" is invalid'
  end
end
