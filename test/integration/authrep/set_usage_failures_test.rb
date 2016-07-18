require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AuthrepSetUsageFailuresTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration

  include TestHelpers::AuthRep

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

    @metric_id_child_1 = next_id
    m1 = Metric.save(:service_id => @service.id, :id => @metric_id_child_1, :name => 'hits_child_1')

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id_child_1,
                    :day => 50, :month => 500, :eternity => 5000)

    @metric_id_child_2 = next_id
    m2 = Metric.save(:service_id => @service.id, :id => @metric_id_child_2, :name => 'hits_child_2')

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id_child_2,
                    :day => 50, :month => 500, :eternity => 5000)

    @metric_id = next_id
    Metric.save(:service_id => @service.id,
                :id => @metric_id,
                :name => 'hits',
                :children => [m1, m2])

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day => 100, :month => 1000, :eternity => 10000)
  end

  test_authrep 'basic failures when setting usage on authreps' do |e|
    Timecop.freeze(Time.utc(2011, 1, 1)) do
      get e, :provider_key => @provider_key,
             :app_id     => @application.id,
             :usage      => {'hits' => '#99'}
      Resque.run!

      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 99, 100)
      assert_authorized
    end

    assert_equal 0, ErrorStorage.count(@service_id)

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      get e, :provider_key => @provider_key,
             :app_id       => @application.id,
             :usage        => {'hits' => '##3'}
      Resque.run!

      assert_error_response :code    => 'usage_value_invalid',
                            :message => 'usage value "##3" for metric "hits" is invalid'
    end

    assert_equal 1, ErrorStorage.count(@service_id)

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      get e, :provider_key => @provider_key,
             :app_id       => @application.id,
             :usage        => {'hits' => '#'}
      Resque.run!

      assert_error_response :code => 'usage_value_invalid',
                            :message => 'usage value "#" for metric "hits" is invalid'
    end

    assert_equal 2, ErrorStorage.count(@service_id)

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      get e, :provider_key => @provider_key,
             :app_id       => @application.id,
             :usage        => {'hits' => ' '}
      Resque.run!

      assert_error_response :code => 'usage_value_invalid',
                            :message => 'usage value for metric "hits" can not be empty'
    end

    assert_equal 3, ErrorStorage.count(@service_id)

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      get e, :provider_key => @provider_key,
             :app_id       => @application.id,
             :usage        => {'hits' => '#55', 'hits_child_1' => '-#55'}
      Resque.run!

      assert_error_response :code => 'usage_value_invalid',
                            :message => 'usage value "-#55" for metric "hits_child_1" is invalid'
    end

    ## the first one to fail, raises the error, and the 55 does not get updated because all
    ## metrics must be correct

    assert_equal 4, ErrorStorage.count(@service_id)

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      get e, :provider_key => @provider_key,
             :app_id       => @application.id
      Resque.run!

      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 99, 100)
      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits_child_1', 'day', 0, 50)
      assert_authorized

      get e, :provider_key => @provider_key,
             :app_id       => @application.id,
             :usage        => {'hits' => '2'}
      Resque.run!

      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 99, 100)
      assert_not_authorized 'usage limits are exceeded'
    end

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      get e, :provider_key => @provider_key,
             :app_id       => @application.id,
             :usage        => {'hits' => '##55'}
      Resque.run!

      assert_error_response :code => 'usage_value_invalid',
                            :message => 'usage value "##55" for metric "hits" is invalid'
    end

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      get e, :provider_key => @provider_key,
             :app_id       => @application.id,
             :usage        => {'hits' => -1}
      Resque.run!

      assert_error_response :code => 'usage_value_invalid',
                            :message => 'usage value "-1" for metric "hits" is invalid'
    end

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      get e, :provider_key => @provider_key,
             :app_id       => @application.id,
             :usage        => {'hitssssss' => '55'}
      Resque.run!

      assert_error_response :code => 'metric_invalid', :status => 404,
                            :message => 'metric "hitssssss" is invalid'
    end

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      get e, :provider_key => @provider_key,
             :app_id       => @application.id,
             :usage        => {'hitssssss' => '55'}
      Resque.run!

      assert_error_response :code => 'metric_invalid', :status => 404,
                            :message => 'metric "hitssssss" is invalid'
    end
  end
end
