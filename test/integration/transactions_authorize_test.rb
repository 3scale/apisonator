require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class TransactionsAuthorizeTest < Test::Unit::TestCase
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::StorageKeys

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!

    setup_provider_fixtures

    @application = Application.save(:service_id => @service.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id,
                                    :plan_name  => @plan_name)

    @metric_id = next_id
    Metric.save(:service_id => @service.id, :id => @metric_id, :name => 'hits')
  end

  test 'successful authorize responds with 200' do
    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id

    assert_equal 200, last_response.status
  end

  test 'successful authorize has custom content type' do
    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id

    assert_includes last_response.content_type, 'application/vnd.3scale-v2.0+xml'
  end

  test 'successful authorize renders plan name' do
    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id

    doc = Nokogiri::XML(last_response.body)
    assert_equal @plan_name, doc.at('status:root plan').content
  end

  test 'response of successful authorize contains authorized flag set to true' do
    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id

    doc = Nokogiri::XML(last_response.body)
    assert_equal 'true', doc.at('status:root authorized').content
  end

  test 'response of successful authorize contains usage reports if the plan has usage limits' do
    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day => 100, :month => 10000)

    Timecop.freeze(Time.utc(2010, 5, 14)) do
      Transactor.report(@provider_key,
                        0 => {'app_id' => @application.id, 'usage' => {'hits' => 3}})
      Resque.run!
    end

    Timecop.freeze(Time.utc(2010, 5, 15)) do
      Transactor.report(@provider_key,
                        0 => {'app_id' => @application.id, 'usage' => {'hits' => 2}})
      Resque.run!
    end

    Timecop.freeze(Time.utc(2010, 5, 15)) do
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id     => @application.id

      doc = Nokogiri::XML(last_response.body)

      usage_reports = doc.at('usage_reports')
      assert_not_nil usage_reports

      day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
      assert_not_nil day
      assert_equal '2010-05-15 00:00:00 +0000', day.at('period_start').content
      assert_equal '2010-05-16 00:00:00 +0000', day.at('period_end').content
      assert_equal '2',                         day.at('current_value').content
      assert_equal '100',                       day.at('max_value').content

      month = usage_reports.at('usage_report[metric = "hits"][period = "month"]')
      assert_not_nil month
      assert_equal '2010-05-01 00:00:00 +0000', month.at('period_start').content
      assert_equal '2010-06-01 00:00:00 +0000', month.at('period_end').content
      assert_equal '5',                         month.at('current_value').content
      assert_equal '10000',                     month.at('max_value').content
    end
  end

  test 'response of successful authorize does not contain usage reports if the plan has no usage limits' do
    Timecop.freeze(Time.utc(2010, 5, 15)) do
      Transactor.report(@provider_key,
                        0 => {'app_id' => @application.id, 'usage' => {'hits' => 2}})

      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id     => @application.id

      doc = Nokogiri::XML(last_response.body)

      assert_nil doc.at('usage_reports')
    end
  end

  test 'fails on invalid provider key' do
    get '/transactions/authorize.xml', :provider_key => 'boo',
                                       :app_id     => @application.id

    assert_error_response :code    => 'provider_key_invalid',
                          :message => 'provider key "boo" is invalid'
  end

  test 'fails on invalid application id' do
    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => 'boo'


    assert_error_response :status  => 404,
                          :code    => 'application_not_found',
                          :message => 'application with id="boo" was not found'
  end

  test 'does not authorize on inactive application' do
    @application.state = :suspended
    @application.save

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id

    assert_not_authorized last_response, 'application is not active'
  end

  test 'does not authorize on exceeded client usage limits' do
    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day => 4)

    Transactor.report(@provider_key,
                      0 => {'app_id' => @application.id, 'usage' => {'hits' => 5}})

    Resque.run!

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id

    assert_not_authorized last_response, 'usage limits are exceeded'
  end

  test 'response contains usage reports marked as exceeded on exceeded client usage limits' do
    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :month => 10, :day => 4)

    Transactor.report(@provider_key,
                      0 => {'app_id' => @application.id, 'usage' => {'hits' => 5}})

    Resque.run!

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id

    doc   = Nokogiri::XML(last_response.body)
    day   = doc.at('usage_report[metric = "hits"][period = "day"]')
    month = doc.at('usage_report[metric = "hits"][period = "month"]')

    assert_equal 'true', day['exceeded']
    assert_nil           month['exceeded']
  end

  # application keys tests

  test 'succeeds if no application key is defined nor passed' do
    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id

    assert_authorized last_response
  end

  test 'succeeds if one application key is defined and the same one is passed' do
    application_key = @application.create_key

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :app_key      => application_key

    assert_authorized last_response
  end

  test 'succeeds if multiple application keys are defined and one of them is passed' do
    application_key_one = @application.create_key
    application_key_two = @application.create_key

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :app_key      => application_key_one

    assert_authorized last_response
  end

  test 'does not authorize if application key is defined but not passed' do
    @application.create_key

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id

    assert_not_authorized last_response, 'application key is missing'
  end

  test 'does not authorize if application key is defined but wrong one is passed' do
    @application.create_key('foo')

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :app_key      => 'bar'

    assert_not_authorized last_response, 'application key "bar" is invalid'
  end

  # referrer filters tests

  test 'succeeds if no referrer filter is defined and no referrer is passed' do
    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id

    assert_authorized last_response
  end

  test 'succeeds if simple domain filter is defined and matching referrer is passed' do
    @application.create_referrer_filter('example.org')

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :referrer     => 'example.org'

    assert_authorized last_response
  end

  test 'succeeds if wildcard domain filter is defined and matching referrer is passed' do
    @application.create_referrer_filter('*.bar.example.org')

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :referrer     => 'foo.bar.example.org'

    assert_authorized last_response
  end

  test 'succeeds if a referrer filter is defined but referrer is bypassed' do
    @application.create_referrer_filter('example.org')

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :referrer     => '*'

    assert_authorized last_response
  end

  test 'does not authorize if domain filter is defined but no referrer is passed' do
    @application.create_referrer_filter('example.org')

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id

    assert_not_authorized last_response, 'referrer is missing'
  end

  test 'does not authorize if simple domain filter is defined but referrer does not match' do
    @application.create_referrer_filter('foo.example.org')

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :referrer     => 'bar.example.org'

    assert_not_authorized last_response, 'referrer "bar.example.org" is not allowed'
  end

  test 'does not authorize if wildcard domain filter is defined but referrer does not match' do
    @application.create_referrer_filter('*.foo.example.org')

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :referrer     => 'baz.bar.example.org'

    assert_not_authorized last_response, 'referrer "baz.bar.example.org" is not allowed'
  end

  # referrer filters presence test

  test 'succeeds if referrer filters are not required' do
    @service.referrer_filters_required = false
    @service.save

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id

    assert_authorized last_response
  end

  test 'succeeds if referrer filters are required and defined' do
    @service.referrer_filters_required = true
    @service.save

    @application.create_referrer_filter('foo.example.org')

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :referrer     => 'foo.example.org'

    assert_authorized last_response
  end

  test 'does not authorize if referrer filters are required but not defined' do
    @service.referrer_filters_required = true
    @service.save

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id

    assert_not_authorized last_response, 'referrer filters are missing'
  end

  # ...

  test 'succeeds on exceeded provider usage limits' do
    UsageLimit.save(:service_id => @master_service_id,
                    :plan_id    => @master_plan_id,
                    :metric_id  => @master_hits_id,
                    :day        => 2)

    3.times do
      Transactor.report(@provider_key,
                        0 => {'app_id' => @application.id, 'usage' => {'hits' => 1}})
    end

    Resque.run!

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id

    assert_equal 200,                               last_response.status
    assert_includes last_response.content_type, 'application/vnd.3scale-v2.0+xml'
  end

  # Legacy authentication support

  test 'successful authorize reports backend hit' do
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id       => @application.id

      Resque.run!

      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_hits_id,
                                                   :month, '20100501')).to_i

      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_authorizes_id,
                                                   :month, '20100501')).to_i
    end
  end

  def test_authorize_with_invalid_provider_key_does_not_report_backend_hit
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      get '/transactions/authorize.xml', :provider_key => 'boo',
                                         :app_id       => @application.id

      Resque.run!

      assert_equal 0, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_authorizes_id,
                                                   :month, '20100501')).to_i
    end
  end

  def test_authorize_with_invalid_application_id_reports_backend_hit
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id       => 'baa'

      Resque.run!

      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_authorizes_id,
                                                   :month, '20100501')).to_i
    end
  end

  def test_authorize_with_inactive_application_reports_backend_hit
    @application.state = :suspended
    @application.save

    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id       => @application.id

      Resque.run!

      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_authorizes_id,
                                                   :month, '20100501')).to_i
    end
  end

  test 'authorize with exceeded usage limits reports backend hit' do
    UsageLimit.save(:service_id => @service_id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day        => 4)

    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      Transactor.report(@provider_key,
                        0 => {'app_id' => @application.id, 'usage' => {'hits' => 5}})
      Resque.run!
    end


    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id       => @application.id

      Resque.run!

      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_authorizes_id,
                                                   :month, '20100501')).to_i
    end
  end

  test 'archives backend hit' do
    path = configuration.archiver.path
    FileUtils.rm_rf(path)

    Timecop.freeze(Time.utc(2010, 5, 11, 11, 54)) do
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id       => @application.id

      Resque.run!

      content = File.read("#{path}/service-#{@master_service_id}/20100511.xml.part")
      content = "<transactions>#{content}</transactions>"

      doc = Nokogiri::XML(content)
      node = doc.at('transaction')

      assert_not_nil node
      assert_equal '2010-05-11 11:54:00', node.at('timestamp').content
      assert_equal '1', node.at("values value[metric_id = \"#{@master_hits_id}\"]").content
      assert_equal '1', node.at("values value[metric_id = \"#{@master_authorizes_id}\"]").content
    end
  end

  private

  def assert_authorized(response)
    assert_equal 200, response.status

    doc = Nokogiri::XML(response.body)
    assert_equal 'true', doc.at('status authorized').content
  end

  def assert_not_authorized(response, reason = nil)
    assert_equal 200, response.status

    doc = Nokogiri::XML(response.body)
    assert_equal 'false', doc.at('status authorized').content
    assert_equal reason,  doc.at('status reason').content if reason
  end
end
