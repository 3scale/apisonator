require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class OauthPredictedUsageTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration

  def setup
    Storage.instance(true).flushdb
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

  test 'does not authorize when current usage + predicted usage exceeds the limits' do
    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day => 4)

    Transactor.report(@provider_key, nil, 0 => {'app_id' => @application.id,
                                           'usage'  => {'hits' => 3}})
    Resque.run!

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :app_id       => @application.id,
                                             :usage        => {'hits' => 2}

    assert_not_authorized 'usage limits are exceeded'
  end

  test 'does not authorize when current usage + predicted usage exceeds the limits with explicit service id' do
    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day => 4)

    Transactor.report(@provider_key, @service.id, 0 => {'app_id' => @application.id,
                                           'usage'  => {'hits' => 3}})
    Resque.run!

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :service_id   => @service.id,
                                             :app_id       => @application.id,
                                             :usage        => {'hits' => 2}

    assert_not_authorized 'usage limits are exceeded'
  end

  test 'succeeds when only limits for the metrics not in the predicted usage are exceeded' do
    metric_one_id = @metric_id

    metric_two_id = next_id
    Metric.save(:service_id => @service.id, :id => metric_two_id, :name => 'hacks')

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => metric_one_id,
                    :day        => 4)

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => metric_two_id,
                    :day        => 4)

    Transactor.report(@provider_key, nil, 0 => {'app_id' => @application.id,
                                           'usage'  => {'hits'  => 2,
                                                        'hacks' => 5}})
    Resque.run!

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :app_id       => @application.id,
                                             :usage        => {'hits' => 1}

    assert_authorized
  end

  test 'succeeds when only limits for the metrics not in the predicted usage are exceeded with explicit service id' do
    metric_one_id = @metric_id

    metric_two_id = next_id
    Metric.save(:service_id => @service.id, :id => metric_two_id, :name => 'hacks')

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => metric_one_id,
                    :day        => 4)

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => metric_two_id,
                    :day        => 4)

    Transactor.report(@provider_key, @service_id, 0 => {'app_id' => @application.id,
                                           'usage'  => {'hits'  => 2,
                                                        'hacks' => 5}})
    Resque.run!

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :service_id   => @service.id,
                                             :app_id       => @application.id,
                                             :usage        => {'hits' => 1}

    assert_authorized
  end

  test 'does not authorize if usage of a parent metric exceeds the limits but only a child metric which does not exceed the limits is in the predicted usage' do
    child_metric_id = next_id
    Metric.save(:service_id => @service.id,
                :parent_id  => @metric_id,
                :id         => child_metric_id,
                :name       => 'queries')

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day        => 4)

    Transactor.report(@provider_key, nil, 0 => {'app_id' => @application.id,
                                           'usage'  => {'hits'  => 5}})
    Resque.run!

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :app_id       => @application.id,
                                             :usage        => {'queries' => 1}

    assert_not_authorized 'usage limits are exceeded'
  end

  test 'does not authorize if usage of a parent metric exceeds the limits but only a child metric which does not exceed the limits is in the predicted usage with explicit service id' do
    child_metric_id = next_id
    Metric.save(:service_id => @service.id,
                :parent_id  => @metric_id,
                :id         => child_metric_id,
                :name       => 'queries')

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day        => 4)

    Transactor.report(@provider_key, @service.id ,0 => {'app_id' => @application.id,
                                           'usage'  => {'hits'  => 5}})
    Resque.run!

    get '/transactions/oauth_authorize.xml', :provider_key => @provider_key,
                                             :service_id   => @service.id,
                                             :app_id       => @application.id,
                                             :usage        => {'queries' => 1}

    assert_not_authorized 'usage limits are exceeded'
  end
end
