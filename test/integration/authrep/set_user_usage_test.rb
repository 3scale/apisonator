require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AuthrepSetUserUsageTest < Test::Unit::TestCase
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

    @default_user_plan_id = next_id
    @default_user_plan_name = 'user plan mobile'

    @service.user_registration_required = false
    @service.default_user_plan_name = @default_user_plan_name
    @service.default_user_plan_id = @default_user_plan_id
    @service.save!

    @application = Application.save(:service_id => @service.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id,
                                    :plan_name  => @plan_name,
                                    :user_required => true)

    @metric_id = next_id

    Metric.save(:service_id => @service.id, :id => @metric_id, :name => 'hits')

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @default_user_plan_id,
                    :metric_id  => @metric_id,
                    :day => 100, :month => 1000, :eternity => 10000)
  end

  test_authrep 'check behavior of set values when passed as usage on authrep' do |e|
    Timecop.freeze(Time.utc(2011, 1, 1)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :user_id => 'user1', :usage => {'hits' => '#97'}},
                          1 => {:app_id => @application.id, :user_id => 'user2', :usage => {'hits' => '#96'}}}
      Resque.run!

      get e, :provider_key => @provider_key,
             :app_id       => @application.id,
             :user_id      => 'user1',
             :usage        => {'hits' => 1}
      Resque.run!

      get e, :provider_key => @provider_key,
             :app_id       => @application.id,
             :user_id      => 'user1',
             :usage        => {'hits' => 1}
      Resque.run!

      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 99, 100)
      assert_authorized
    end

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      get e, :provider_key => @provider_key,
             :app_id       => @application.id,
             :user_id      => 'user1',
             :usage        => {'hits' => '#101'}
      Resque.run!

      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 99, 100)
      assert_not_authorized 'usage limits are exceeded'
    end

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :user_id => 'user1', :usage => {'hits' => 2}},
                          1 => {:app_id => @application.id, :user_id => 'user2', :usage => {'hits' => 2}}}
      Resque.run!

      get e, :provider_key => @provider_key,
             :app_id       => @application.id,
             :user_id      => 'user1',
             :usage        => {'hits' => 2}
      Resque.run!

      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 101, 100)
      assert_not_authorized 'usage limits are exceeded'

      get e, :provider_key => @provider_key,
             :app_id       => @application.id,
             :user_id      => 'user2',
             :usage        => {'hits' => 2}
      Resque.run!

      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 100, 100)
      assert_authorized
    end

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      get e, :provider_key => @provider_key,
             :app_id       => @application.id,
             :user_id      => 'user1',
             :usage        => {'hits' => '#99'}
      Resque.run!

      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 99, 100)
      assert_authorized

      get e, :provider_key => @provider_key,
             :app_id       => @application.id,
             :user_id      => 'user2',
             :usage        => {'hits' => '#98'}
      Resque.run!

      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 98, 100)
      assert_authorized

      get e, :provider_key => @provider_key,
             :app_id       => @application.id,
             :user_id      => 'user2',
             :usage        => {'hits' => '#0'}
      Resque.run!

      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 0, 100)
      assert_authorized
    end
  end

  test_authrep 'check behaviour of set values with caching and authrep' do |e|
    Timecop.freeze(Time.utc(2011, 1, 1)) do
      post '/transactions.xml',
          :provider_key => @provider_key,
          :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 80}, :user_id => 'user1'}}
      Resque.run!

      10.times do |cont|
        if cont.even?
          get e, :provider_key => @provider_key,
                 :app_id       => @application.id,
                 :user_id      => 'user1',
                 :usage        => {'hits' => "##{80 + (cont+1)*2}"}
        else
          get e, :provider_key => @provider_key,
                 :app_id       => @application.id,
                 :user_id      => 'user1',
                 :usage        => {'hits' => '2'}
        end
        Resque.run!

        assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 80 + (cont+1)*2, 100)
        assert_authorized
      end

      get e, :provider_key => @provider_key,
             :app_id       => @application.id,
             :user_id      => 'user1'
      Resque.run!

      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 100, 100)
      assert_authorized

      10.times do |cont|
        get e, :provider_key => @provider_key,
               :app_id       => @application.id,
               :user_id      => 'user1',
               :usage        => {'hits' => 2}
        Resque.run!

        assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 100, 100)
        assert_not_authorized 'usage limits are exceeded'
      end

      10.times do |cont|
        get e, :provider_key => @provider_key,
               :app_id       => @application.id,
               :user_id      => 'user1',
               :usage        => {'hits' => "##{100 + (cont+1)*-2}"}
        Resque.run!

        assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 100 + (cont+1)*-2, 100)
        assert_authorized
      end
    end
  end
end
