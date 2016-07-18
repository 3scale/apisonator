require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AuthorizeSetUsageTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!
    Memoizer.reset!

    setup_provider_fixtures

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

  test 'basic set of usage with report and authorize' do
    time = Time.utc(2011, 1, 1)
    Timecop.freeze(time) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => '#3'}}}
      Resque.run!
    end

    time = Time.utc(2011, 1, 2)
    Timecop.freeze(time) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits_child_2' => 2}}}
      Resque.run!
    end

    time = Time.utc(2011, 1, 1, 13, 0, 0)
    Timecop.freeze(time) do
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id     => @application.id

      assert_usage_report(time, 'hits', 'day', 3, 100)
      assert_usage_report(time, 'hits_child_2', 'day', 0, 50)
      assert_usage_report(time, 'hits_child_1', 'day', 0, 50)

      assert_usage_report(time, 'hits', 'month', 5, 1000)
      assert_usage_report(time, 'hits_child_2', 'month', 2, 500)
      assert_usage_report(time, 'hits_child_1', 'month', 0, 500)
    end

    time = Time.utc(2011, 1, 2, 0, 0, 0)
    Timecop.freeze(time) do
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id     => @application.id

      assert_usage_report(time, 'hits', 'day', 2, 100)
      assert_usage_report(time, 'hits_child_2', 'day', 2, 50)
      assert_usage_report(time, 'hits_child_1', 'day', 0, 50)

      assert_usage_report(time, 'hits', 'month', 5, 1000)
      assert_usage_report(time, 'hits_child_2', 'month', 2, 500)
      assert_usage_report(time, 'hits_child_1', 'month', 0, 500)
    end

    time = Time.utc(2011, 1, 2)
    Timecop.freeze(time) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits_child_2' => '#10'}}}
      Resque.run!
    end

    time = Time.utc(2011, 1, 2, 13, 0, 0)
    Timecop.freeze(time) do
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id     => @application.id

      assert_usage_report(time, 'hits', 'day', 10, 100)
      assert_usage_report(time, 'hits_child_2', 'day', 10, 50)
      assert_usage_report(time, 'hits_child_1', 'day', 0, 50)

      assert_usage_report(time, 'hits', 'month', 10, 1000)
      assert_usage_report(time, 'hits_child_2', 'month', 10, 500)
      assert_usage_report(time, 'hits_child_1', 'month', 0, 500)
    end

    time = Time.utc(2011, 1, 2)
    Timecop.freeze(time) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits_child_1' => '#6'}}}
      Resque.run!
    end

    time = Time.utc(2011, 1, 2, 13, 0, 0)
    Timecop.freeze(time) do
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id     => @application.id

      assert_usage_report(time, 'hits', 'day', 6, 100)
      assert_usage_report(time, 'hits_child_2', 'day', 10, 50)
      assert_usage_report(time, 'hits_child_1', 'day', 6, 50)

      assert_usage_report(time, 'hits', 'month', 6, 1000)
      assert_usage_report(time, 'hits_child_2', 'month', 10, 500)
      assert_usage_report(time, 'hits_child_1', 'month', 6, 500)

      assert_usage_report(time, 'hits', 'eternity', 6, 10000)
      assert_usage_report(time, 'hits_child_2', 'eternity', 10, 5000)
      assert_usage_report(time, 'hits_child_1', 'eternity', 6, 5000)
    end

    ## this case is problematic, since the set on the hits will be the value of the last child evaluated, going to increase
    ## WTF factor
    time = Time.utc(2011, 1, 2)
    Timecop.freeze(time) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits_child_1' => '#11', 'hits_child_2' => '#12'}}}
      Resque.run!
    end

    time = Time.utc(2011, 1, 2, 13, 0, 0)
    Timecop.freeze(time) do
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id     => @application.id

      assert_usage_report(time, 'hits', 'day', 12, 100)
      assert_usage_report(time, 'hits_child_2', 'day', 12, 50)
      assert_usage_report(time, 'hits_child_1', 'day', 11, 50)

      assert_usage_report(time, 'hits', 'month', 12, 1000)
      assert_usage_report(time, 'hits_child_2', 'month', 12, 500)
      assert_usage_report(time, 'hits_child_1', 'month', 11, 500)

      assert_usage_report(time, 'hits', 'eternity', 12, 10000)
      assert_usage_report(time, 'hits_child_2', 'eternity', 12, 5000)
      assert_usage_report(time, 'hits_child_1', 'eternity', 11, 5000)
    end
  end

  test 'proper behaviour of set usage when passed by parameter on authorize' do
    Timecop.freeze(Time.utc(2011, 1, 1)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 99}}}
      Resque.run!

      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :usage      => {'hits' => '#2'}

      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 99, 100)
      assert_authorized
    end

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => '#101'}}}
      Resque.run!

      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :usage      => {'hits' => '#2'}

      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 101, 100)
      assert_authorized
    end

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => '#50'}}}
      Resque.run!

      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :usage      => {'hits' => '#101'}

      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 50, 100)
      assert_not_authorized 'usage limits are exceeded'
    end
  end

  test 'check setting values with caching and authorize' do
     Timecop.freeze(Time.utc(2011, 1, 1)) do
       post '/transactions.xml',
         :provider_key => @provider_key,
         :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 80}}}
       Resque.run!

       10.times do |cont|
         if cont.even?
           get '/transactions/authorize.xml', :provider_key => @provider_key,
                                              :app_id     => @application.id,
                                              :usage      => {'hits' => "##{80 + (cont+1)*2}"}
         else
           get '/transactions/authorize.xml', :provider_key => @provider_key,
                                               :app_id     => @application.id,
                                               :usage      => {'hits' => 2}
         end

         assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 80 + (cont)*2, 100)
         assert_authorized

         post '/transactions.xml',
            :provider_key => @provider_key,
            :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => "##{80 + (cont+1)*2}"}}}
         Resque.run!
       end

       10.times do
         get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id     => @application.id,
                                         :usage      => {'hits' => 2}

         assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 100, 100)
         assert_not_authorized 'usage limits are exceeded'
       end

       10.times do |cont|
         get '/transactions/authorize.xml', :provider_key => @provider_key,
                                            :app_id     => @application.id,
                                            :usage      => {'hits' => "##{100 + (cont+1)*-2}"}

         assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 100 + (cont)*-2, 100)
         assert_authorized

         post '/transactions.xml',
             :provider_key => @provider_key,
             :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => "##{100 + (cont+1)*-2}"}}}
         Resque.run!
       end
     end
  end
end
