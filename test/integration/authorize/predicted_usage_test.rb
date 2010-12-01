require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AuthorizePredictedUsageTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration

  def setup
    Storage.instance(true).flushdb
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

  test 'does not authorize when current usage + predicted usage exceeds the limits' do
    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day => 4)

    Transactor.report(@provider_key, 0 => {'app_id' => @application.id,
                                           'usage'  => {'hits' => 3}})
    Resque.run!

    get '/transactions/authorize.xml', :provider_key => @provider_key,
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

    Transactor.report(@provider_key, 0 => {'app_id' => @application.id,
                                           'usage'  => {'hits'  => 2,
                                                        'hacks' => 5}})
    Resque.run!

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application.id,
                                       :usage        => {'hits' => 1}

    assert_authorized
  end
end
