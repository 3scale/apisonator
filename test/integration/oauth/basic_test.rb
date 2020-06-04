require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class OauthBasicTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::Extensions

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!
    Memoizer.reset!

    setup_oauth_provider_fixtures

    @application = Application.save(:service_id => @service.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id,
                                    :plan_name  => @plan_name)

    @metric_id = next_id
    Metric.save(:service_id => @service.id, :id => @metric_id, :name => 'hits')
  end

  test 'successful authorize responds with 200' do
    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :app_id       => @application.id

    assert_equal 200, last_response.status
  end

  test_nobody :get, '/transactions/oauth_authorize.xml' do
    { provider_key: @provider_key, app_id: @application.id }
  end

  test 'successful authorize has custom content type' do
    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :app_id       => @application.id

    assert_includes last_response.content_type, 'application/vnd.3scale-v2.0+xml'
  end

  test 'successful authorize renders plan name' do
    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :app_id     => @application.id

    doc = Nokogiri::XML(last_response.body)

    assert_equal @plan_name, doc.at('status:root plan').content
  end

  test 'response of successful authorize contains authorized flag set to true' do
    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :app_id     => @application.id

    doc = Nokogiri::XML(last_response.body)

    assert_equal 'true', doc.at('status:root authorized').content
  end

  test 'response of successful authorize contains application data' do
    @application = Application.save(:service_id   => @service.id,
                                    :id           => next_id,
                                    :state        => :active,
                                    :plan_id      => @plan_id,
                                    :plan_name    => @plan_name,
                                    :redirect_url => 'http://3scale.net')
    @application.create_key

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :app_id     => @application.id

    doc = Nokogiri::XML(last_response.body)

    assert_equal @application.id,           doc.at('application/id').content
    assert_equal @application.keys.first,   doc.at('application/key').content
    assert_equal @application.redirect_url, doc.at('application/redirect_url').content
  end

  test 'response of successful authorize contains usage reports if the plan has usage limits' do
    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day => 100, :month => 10000)

    Timecop.freeze(Time.utc(2010, 5, 14)) do
      Transactor.report(@provider_key, @service.id,
                        0 => {'app_id' => @application.id, 'usage' => {'hits' => 3}})
      Resque.run!
    end

    Timecop.freeze(Time.utc(2010, 5, 15)) do
      Transactor.report(@provider_key, nil,
                        0 => {'app_id' => @application.id, 'usage' => {'hits' => 2}})
      Resque.run!
    end

    Timecop.freeze(Time.utc(2010, 5, 15)) do
      get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
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
      Transactor.report(@provider_key, @service.id,
                        0 => {'app_id' => @application.id, 'usage' => {'hits' => 2}})

      get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                               :service_id   => @service.id,
                                               :app_id     => @application.id

      doc = Nokogiri::XML(last_response.body)

      assert_nil doc.at('usage_reports')
    end
  end

  test 'fails on invalid provider key' do
    provider_key = 'invalid_key'

    get '/transactions/oauth_authorize.xml', :provider_key => provider_key,
                                             :app_id => @application.id

    assert_error_resp_with_exc(ProviderKeyInvalidOrServiceMissing.new(provider_key))
  end

  test 'fails on invalid provider key with no body' do
    get '/transactions/oauth_authorize.xml', {
        :provider_key => 'boo',
        :app_id     => @application.id
      },
      'HTTP_3SCALE_OPTIONS' => Extensions::NO_BODY

    assert_equal 403, last_response.status
    assert_equal '', last_response.body
  end

  test 'fails on invalid application id' do
    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :app_id       => 'boo'

    assert_error_response :status  => 404,
                          :code    => 'application_not_found',
                          :message => 'application with id="boo" was not found'
  end

  test 'fails when the application exists but in a different provider' do
    diff_provider_key = next_id
    service = Service.save!(:provider_key => diff_provider_key, :id => next_id)
    application = Application.save(:service_id => service.id,
                                   :id         => next_id,
                                   :state      => :active,
                                   :plan_id    => next_id,
                                   :plan_name  => 'free')

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :service_id   => service.id,
                                             :app_id       => application.id

    assert_error_response :status  => 403,
                          :code    => 'service_id_invalid',
                          :message => "service id \"#{service.id}\" is invalid"
  end

  test 'fails on invalid application id with no body' do
    get '/transactions/oauth_authorize.xml', {
        :provider_key => @provider_key,
        :app_id       => 'boo'
      },
      'HTTP_3SCALE_OPTIONS' => Extensions::NO_BODY

    assert_equal 404, last_response.status
    assert_equal '', last_response.body
  end

  test 'fails on missing application id' do
    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key

    assert_error_response :status  => 404,
                          :code    => 'application_not_found'
  end

  test 'does not authorize on inactive application' do
    @application.state = :suspended
    @application.save

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :app_id       => @application.id

    assert_equal 409, last_response.status
    assert_not_authorized 'application is not active'
  end

  test 'does not authorize on inactive application with no body' do
    @application.state = :suspended
    @application.save

    get '/transactions/oauth_authorize.xml', {
        :provider_key => @provider_key,
        :app_id       => @application.id
      },
      'HTTP_3SCALE_OPTIONS' => Extensions::NO_BODY

    assert_equal 409, last_response.status
    assert_equal '', last_response.body
  end

  test 'does not authorize on exceeded client usage limits' do
    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day => 4)

    Transactor.report(@provider_key, @service.id,
                      0 => {'app_id' => @application.id, 'usage' => {'hits' => 5}})
    Resque.run!

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :service_id => @service.id,
                                             :app_id     => @application.id

    assert_equal 409, last_response.status
    assert_not_authorized 'usage limits are exceeded'
  end

  test 'does not authorize on exceeded client usage limits with no body' do
    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day => 4)

    Transactor.report(@provider_key, nil,
                      0 => {'app_id' => @application.id, 'usage' => {'hits' => 5}})
    Resque.run!

    get '/transactions/oauth_authorize.xml', {
        :provider_key => @provider_key,
        :app_id     => @application.id
      },
      'HTTP_3SCALE_OPTIONS' => Extensions::NO_BODY

    assert_equal 409, last_response.status
    assert_equal '', last_response.body
  end

  test 'a request without "no_body" works as expected after making a request with "no_body"' do
    # A call with no_body enabled only loads the limits that affect the metrics
    # of the request. This test checks that all the limits appear in the XML of
    # a subsequent call.

    UsageLimit.save(
      service_id: @service_id, plan_id: @plan_id, metric_id: @metric_id, day: 10
    )

    other_metric_id = next_id
    Metric.save(service_id: @service_id, id: other_metric_id, name: 'some_metric')
    UsageLimit.save(
      service_id: @service_id, plan_id: @plan_id, metric_id: other_metric_id, day: 20
    )

    get '/transactions/oauth_authorize.xml',
        { provider_key: @provider_key, app_id: @application.id },
        'HTTP_3SCALE_OPTIONS' => Extensions::NO_BODY

    assert_equal 200, last_response.status
    assert_equal '', last_response.body

    get '/transactions/authorize.xml',
        { provider_key: @provider_key, app_id: @application.id }

    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    assert_not_nil doc.at('usage_report[metric = "hits"][period = "day"]')
    assert_not_nil doc.at('usage_report[metric = "some_metric"][period = "day"]')
  end

  test 'response contains usage reports marked as exceeded on exceeded client usage limits' do
    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :month => 10, :day => 4)

    Transactor.report(@provider_key, nil,
                      0 => {'app_id' => @application.id, 'usage' => {'hits' => 5}})
    Resque.run!

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :app_id       => @application.id

    doc   = Nokogiri::XML(last_response.body)
    day   = doc.at('usage_report[metric = "hits"][period = "day"]')
    month = doc.at('usage_report[metric = "hits"][period = "month"]')

    assert_equal 'true', day['exceeded']
    assert_nil           month['exceeded']
  end

  test 'succeeds on exceeded provider usage limits' do
    UsageLimit.save(:service_id => @master_service_id,
                    :plan_id    => @master_plan_id,
                    :metric_id  => @master_hits_id,
                    :day        => 2)

    3.times do
      Transactor.report(@provider_key, nil,
                        0 => {'app_id' => @application.id, 'usage' => {'hits' => 1}})
    end
    Resque.run!

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :app_id       => @application.id,
                                             :service_id   => @service.id
    assert_authorized
  end

  test 'succeeds on eternity limits' do
    Timecop.freeze(Time.utc(2010, 5, 15)) do
      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month => 4)

      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :eternity   => 10)

      3.times do
        Transactor.report(@provider_key, nil,
                          0 => {'app_id' => @application.id, 'usage' => {'hits' => 1}})
      end
      Resque.run!

      get '/transactions/oauth_authorize.xml',  :provider_key => @provider_key,
                                                :app_id       => @application.id

      doc   = Nokogiri::XML(last_response.body)
      month   = doc.at('usage_report[metric = "hits"][period = "month"]')

      assert_not_nil month
      assert_equal '2010-05-01 00:00:00 +0000', month.at('period_start').content
      assert_equal '2010-06-01 00:00:00 +0000', month.at('period_end').content
      assert_equal '3', month.at('current_value').content
      assert_equal '4', month.at('max_value').content
      assert_nil   month['exceeded']

      eternity   = doc.at('usage_report[metric = "hits"][period = "eternity"]')

      assert_not_nil  eternity
      assert_nil      eternity.at('period_start')
      assert_nil      eternity.at('period_end')
      assert_equal    '3', eternity.at('current_value').content
      assert_equal    '10', eternity.at('max_value').content
      assert_nil      eternity['exceeded']
    end
  end

  test 'does not authorize on eternity limits' do
    Timecop.freeze(Time.utc(2010, 5, 15)) do
      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month => 20)

      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :eternity   => 2)

      3.times do
        Transactor.report(@provider_key, nil,
                          0 => {'app_id' => @application.id, 'usage' => {'hits' => 1}})
      end
      Resque.run!

      get '/transactions/oauth_authorize.xml',  :provider_key => @provider_key,
                                                :app_id       => @application.id

      doc   = Nokogiri::XML(last_response.body)
      month   = doc.at('usage_report[metric = "hits"][period = "month"]')

      assert_not_nil month
      assert_equal  '2010-05-01 00:00:00 +0000', month.at('period_start').content
      assert_equal  '2010-06-01 00:00:00 +0000', month.at('period_end').content
      assert_equal  '3', month.at('current_value').content
      assert_equal  '20', month.at('max_value').content
      assert_nil    month['exceeded']

      eternity   = doc.at('usage_report[metric = "hits"][period = "eternity"]')

      assert_not_nil  eternity
      assert_nil      eternity.at('period_start')
      assert_nil      eternity.at('period_end')
      assert_equal    '3', eternity.at('current_value').content
      assert_equal    '2', eternity.at('max_value').content
      assert_equal    'true', eternity['exceeded']
    end
  end

  test 'eternity is not returned if the limit on it is not defined' do
    Timecop.freeze(Time.utc(2010, 5, 15)) do
      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month => 20)

      Transactor.report(@provider_key, nil,
                        0 => {'app_id' => @application.id, 'usage' => {'hits' => 1}})
      Resque.run!

      get '/transactions/oauth_authorize.xml',  :provider_key => @provider_key,
                                                :app_id       => @application.id

      doc   = Nokogiri::XML(last_response.body)
      month   = doc.at('usage_report[metric = "hits"][period = "month"]')
      eternity   = doc.at('usage_report[metric = "hits"][period = "eternity"]')

      assert_not_nil month
      assert_nil     eternity
    end
  end

  test 'usage must be an array regression' do
    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                     :app_id       => @application.id,
                                     :usage        => ''

    assert_equal 403, last_response.status

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                     :app_id       => @application.id,
                                     :usage        => '1001'

    assert_equal 403, last_response.status
  end

  test 'auth using registered (service_token, service_id) instead of provider key responds 200' do
    service_token = 'a_token'
    service_id = @service_id

    ServiceToken.save(service_token, service_id)

    get '/transactions/oauth_authorize.xml', :service_token => service_token,
                                             :service_id => service_id,
                                             :app_id => @application.id

    assert_equal 200, last_response.status
  end

  test 'auth using valid service token and blank service ID fails' do
    service_token = 'a_token'
    blank_service_ids = ['', nil]

    blank_service_ids.each do |blank_service_id|
      get '/transactions/oauth_authorize.xml', :service_token => service_token,
                                               :service_id => blank_service_id,
                                               :app_id => @application.id

      assert_error_resp_with_exc(ThreeScale::Backend::ServiceIdMissing.new)
    end
  end

  test 'auth using blank service token and valid service ID fails' do
    service_id = @service_id
    blank_service_tokens = ['', nil]

    blank_service_tokens.each do |blank_service_token|
      get '/transactions/oauth_authorize.xml', :service_token => blank_service_token,
                                               :service_id => service_id,
                                               :app_id => @application.id

      assert_error_resp_with_exc(ThreeScale::Backend::ProviderKeyOrServiceTokenRequired.new)
    end
  end

  test 'auth using registered token but with non-existing service ID fails' do
    service_token = 'a_token'
    service_id = 'id_non_existing_service'

    ServiceToken.save(service_token, service_id)

    get '/transactions/oauth_authorize.xml', :service_token => service_token,
                                             :service_id => service_id,
                                             :app_id => @application.id

    assert_error_resp_with_exc(
      ThreeScale::Backend::ServiceTokenInvalid.new service_token, service_id)
  end

  test 'auth using valid provider key and invalid service token responds with 200' do
    provider_key = @provider_key
    service_token = nil

    get '/transactions/oauth_authorize.xml', :provider_key => provider_key,
                                             :service_token => service_token,
                                             :app_id => @application.id

    assert_equal 200, last_response.status
  end

  test 'auth using non-existing provider key and saved (service token, service id) fails' do
    provider_key = 'non_existing_key'
    service_token = 'a_token'
    service_id = @service_id

    ServiceToken.save(service_token, service_id)

    get '/transactions/oauth_authorize.xml', :provider_key => provider_key,
                                             :service_token => service_token,
                                             :service_id => service_id,
                                             :app_id => @application.id

    assert_error_resp_with_exc(ThreeScale::Backend::ProviderKeyInvalid.new(provider_key))
  end

  test 'resp headers have rejection reason when 409 and option is in the params' do
    max_usage_day = 1

    UsageLimit.save(:service_id => @service.id,
                    :plan_id => @plan_id,
                    :metric_id => @metric_id,
                    :day => max_usage_day)

    get '/transactions/oauth_authorize.xml', {
        :provider_key => @provider_key,
        :app_id => @application.id,
        :usage => { 'hits' => max_usage_day + 1 },
      },
      'HTTP_3SCALE_OPTIONS' => Extensions::REJECTION_REASON_HEADER

    assert_equal 409, last_response.status
    assert_equal 'limits_exceeded', last_response.header['3scale-rejection-reason']
  end

  test 'resp headers do not have rejection reason when 409 and option is not in the params' do
    max_usage_day = 1

    UsageLimit.save(:service_id => @service.id,
                    :plan_id => @plan_id,
                    :metric_id => @metric_id,
                    :day => max_usage_day)

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :app_id => @application.id,
                                             :usage => { 'hits' => max_usage_day + 1 }

    assert_equal 409, last_response.status
    assert_nil last_response.header['3scale-rejection-reason']
  end

  test 'response includes hierarchy information for metrics affected by usage limits' do
    plan_id          = next_id
    parent           = 'parent_metric'
    parent_id        = next_id
    metric_child1    = 'child_metric_1'
    metric_child1_id = next_id
    metric_child2    = 'child_metric_2'
    metric_child2_id = next_id
    parent_limit = 5

    application = Application.save(:service_id => @service.id,
                                   :id         => next_id,
                                   :state      => :active,
                                   :plan_id    => plan_id,
                                   :plan_name  => 'someplan')

    Metric.save(:service_id => @service.id, :id => parent_id, :name => parent)
    Metric.save(:service_id => @service.id, :id => metric_child1_id,
                :name => metric_child1, parent_id: parent_id)
    Metric.save(:service_id => @service.id, :id => metric_child2_id,
                :name => metric_child2, parent_id: parent_id)

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => plan_id,
                    :metric_id  => parent_id,
                    :day => parent_limit)
    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => plan_id,
                    :metric_id  => metric_child1_id,
                    :day => parent_limit + 1)

    assertions = lambda do |hierarchy = true|
      doc = Nokogiri::XML(last_response.body)
      hierarchy_info = doc.at('hierarchy')
      if hierarchy
        assert_not_nil hierarchy_info
        parent_info = hierarchy_info.at("metric[name = '#{parent}']")
        assert_not_nil parent_info
        children_list = parent_info.attribute('children')
        assert_not_nil children_list
        assert_equal [metric_child1, metric_child2].sort, children_list.value.split.sort
      else
        assert_nil hierarchy_info
      end
    end

    # We have 1 parent metric and 2 children metrics, one of them limited.
    # When we add usage over the "hits" limit for the unlimited metric, we
    # should see an auth denied, and also children information in the hits usage
    # report (and none elsewhere), unless we use the "flat_usage" extension.

    Timecop.freeze(Time.utc(2010, 5, 15)) do
      get '/transactions/oauth_authorize.xml', {
          :provider_key => @provider_key,
          :app_id       => application.id,
          :usage        => { metric_child2 => parent_limit },
        },
        'HTTP_3SCALE_OPTIONS' => Extensions::HIERARCHY
      Resque.run!

      assert_authorized
      assertions.call

      get '/transactions/oauth_authorize.xml', {
          :provider_key => @provider_key,
          :app_id       => application.id,
          :usage        => { metric_child1 => 0, metric_child2 => 0 },
        },
        'HTTP_3SCALE_OPTIONS' => Extensions::HIERARCHY
      Resque.run!

      assert_authorized
      assertions.call

      get '/transactions/oauth_authorize.xml', {
          :provider_key => @provider_key,
          :app_id       => application.id,
        },
        'HTTP_3SCALE_OPTIONS' => Extensions::HIERARCHY
      Resque.run!

      assert_authorized
      assertions.call

      get '/transactions/oauth_authorize.xml', {
          :provider_key => @provider_key,
          :app_id       => application.id,
          :usage        => { metric_child2 => parent_limit + 1 },
        },
        'HTTP_3SCALE_OPTIONS' => Extensions::HIERARCHY
      Resque.run!

      assert_not_authorized
      assertions.call

      # no hierarchy parameter
      get '/transactions/oauth_authorize.xml',
        :provider_key => @provider_key,
        :app_id       => application.id,
        :usage        => { metric_child2 => parent_limit + 1 }
      Resque.run!

      assert_not_authorized
      assertions.call false

      # Test that hitting children over the parent limit does not translate to
      # the parent so that the call is still authorized.
      get '/transactions/oauth_authorize.xml', {
          :provider_key => @provider_key,
          :app_id       => application.id,
          :usage        => { metric_child2 => parent_limit + 1 },
        },
        'HTTP_3SCALE_OPTIONS' => Extensions::FLAT_USAGE
      Resque.run!

      assert_authorized
      assertions.call false
      #
      get '/transactions/oauth_authorize.xml', {
          :provider_key => @provider_key,
          :app_id       => application.id,
          :usage        => { metric_child1 => parent_limit + 1,
                             metric_child2 => parent_limit + 1 },
        },
        'HTTP_3SCALE_OPTIONS' => Extensions::FLAT_USAGE
      Resque.run!

      assert_authorized
      assertions.call false

      # Using flat usage still goes over the limits of specified metrics
      get '/transactions/oauth_authorize.xml', {
          :provider_key => @provider_key,
          :app_id       => application.id,
          :usage        => { parent => parent_limit + 1 },
        },
        'HTTP_3SCALE_OPTIONS' => Extensions::FLAT_USAGE
      Resque.run!

      assert_not_authorized
      assertions.call false

      get '/transactions/oauth_authorize.xml', {
          :provider_key => @provider_key,
          :app_id       => application.id,
          :usage        => { metric_child1 => parent_limit + 1 + 1 },
        },
        'HTTP_3SCALE_OPTIONS' => Extensions::FLAT_USAGE
      Resque.run!

      assert_not_authorized
      assertions.call false

    end
  end

  test 'returns error when the usage includes a metric that does not exist' do
    get '/transactions/oauth_authorize.xml',
        {
          provider_key: @provider_key,
          app_id: @application.id,
          usage: { 'non_existing' => 1 }
        }

    assert_error_resp_with_exc(ThreeScale::Backend::MetricInvalid.new('non_existing'))
  end

  test 'returns error when the usage includes a metric that does not exist and no_body=true' do
    get '/transactions/oauth_authorize.xml',
        {
          provider_key: @provider_key,
          app_id: @application.id,
          usage: { 'hits' => 1, 'non_existing' => 1 }
        },
        'HTTP_3SCALE_OPTIONS' => Extensions::NO_BODY

    assert_equal ThreeScale::Backend::MetricInvalid.new('non_existing').http_code,
                 last_response.status
  end
end
