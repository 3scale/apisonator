require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AuthrepSetUsageTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::StorageKeys

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

  test 'basic set of usage with authrep' do
    Timecop.freeze(Time.utc(2011, 1, 1)) do
      get '/transactions/authrep.xml',  :provider_key => @provider_key,
                                        :app_id      => @application.id,
                                        :usage       => {'hits' => '#3'}
      Backend::Transactor.process_full_batch
      Resque.run!
    end

    Timecop.freeze(Time.utc(2011, 1, 2)) do
      get '/transactions/authrep.xml',  :provider_key => @provider_key,
                                        :app_id      => @application.id,
                                        :usage       => {'hits_child_2' => '2'}
      Backend::Transactor.process_full_batch
      Resque.run!
    end

    Timecop.freeze(Time.utc(2011, 1, 1, 13, 0, 0)) do

      get '/transactions/authrep.xml',  :provider_key => @provider_key,
                                        :app_id     => @application.id
      Backend::Transactor.process_full_batch
      Resque.run!

      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 3, 100)
      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits_child_2', 'day', 0, 50)
      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits_child_1', 'day', 0, 50)

      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'month', 5, 1000)
      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits_child_2', 'month', 2, 500)
      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits_child_1', 'month', 0, 500)
    end

    Timecop.freeze(Time.utc(2011, 1, 2, 13, 0, 0)) do
      get '/transactions/authrep.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id
      Backend::Transactor.process_full_batch
      Resque.run!

      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits', 'day', 2, 100)
      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits_child_2', 'day', 2, 50)
      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits_child_1', 'day', 0, 50)

      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits', 'month', 5, 1000)
      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits_child_2', 'month', 2, 500)
      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits_child_1', 'month', 0, 500)

      get '/transactions/authrep.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :usage => {'hits_child_2' => '#10'}
      Backend::Transactor.process_full_batch
      Resque.run!

      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits', 'day', 10, 100)
      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits_child_2', 'day', 10, 50)
      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits_child_1', 'day', 0, 50)

      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits', 'month', 10, 1000)
      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits_child_2', 'month', 10, 500)
      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits_child_1', 'month', 0, 500)

      get '/transactions/authrep.xml', :provider_key => @provider_key,
                                         :app_id     => @application.id,
                                         :usage => {'hits_child_1' => '#6'}
      Backend::Transactor.process_full_batch
      Resque.run!

      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits', 'day', 6, 100)
      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits_child_2', 'day', 10, 50)
      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits_child_1', 'day', 6, 50)

      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits', 'month', 6, 1000)
      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits_child_2', 'month', 10, 500)
      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits_child_1', 'month', 6, 500)

      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits', 'eternity', 6, 10000)
      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits_child_2', 'eternity', 10, 5000)
      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits_child_1', 'eternity', 6, 5000)
    end

    ## this case is problematic, since the set on the hits will be the value of the last child evaluated, going to increase
    ## WTF factor
    Timecop.freeze(Time.utc(2011, 1, 2, 13, 0, 0)) do
      get '/transactions/authrep.xml', :provider_key => @provider_key,
                                         :app_id     => @application.id,
                                         :usage => {'hits_child_1' => '#11', 'hits_child_2' => '#12'}
      Backend::Transactor.process_full_batch
      Resque.run!

      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits', 'day', 12, 100)
      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits_child_2', 'day', 12, 50)
      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits_child_1', 'day', 11, 50)

      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits', 'month', 12, 1000)
      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits_child_2', 'month', 12, 500)
      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits_child_1', 'month', 11, 500)

      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits', 'eternity', 12, 10000)
      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits_child_2', 'eternity', 12, 5000)
      assert_usage_report(Time.utc(2011, 1, 2, 13, 0, 0), 'hits_child_1', 'eternity', 11, 5000)
    end
  end

  test 'proper behaviour of set usage when passed by parameter on authrep' do
    Timecop.freeze(Time.utc(2011, 1, 1)) do
      get '/transactions/authrep.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :usage      => {'hits' => '99'}
      Resque.run!

      get '/transactions/authrep.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :usage      => {'hits' => '#2'}
      Resque.run!

      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 2, 100)
      assert_authorized
    end

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => '#101'}}}
      Resque.run!

      get '/transactions/authrep.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :usage      => {'hits' => '#2'}
      Resque.run!

      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 2, 100)
      assert_authorized

      get '/transactions/authrep.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :usage      => {'hits' => '98'}
      Resque.run!

      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 100, 100)
      assert_authorized

      get '/transactions/authrep.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :usage      => {'hits' => '98'}
      Resque.run!

      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 100, 100)
      assert_not_authorized 'usage limits are exceeded'
    end

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      get '/transactions/authrep.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :usage      => {'hits' => '#50'}
      Resque.run!

      get '/transactions/authrep.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :usage      => {'hits' => '#101'}
      Resque.run!

      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 50, 100)
      assert_not_authorized 'usage limits are exceeded'
    end

  end

  test 'check setting values with caching and authrep' do
     Timecop.freeze(Time.utc(2011, 1, 1)) do
       post '/transactions.xml',
         :provider_key => @provider_key,
         :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 80}}}
       Resque.run!

       10.times do |cont|
         if cont%2==0
           get '/transactions/authrep.xml', :provider_key => @provider_key,
                                              :app_id     => @application.id,
                                              :usage      => {'hits' => "##{80 + (cont+1)*2}"}
           Resque.run!
         else
           get '/transactions/authrep.xml', :provider_key => @provider_key,
                                               :app_id     => @application.id,
                                               :usage      => {'hits' => 2}
           Resque.run!
         end

         assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 80 + (cont+1)*2, 100)
         assert_authorized
       end

       10.times do |cont|
         get '/transactions/authrep.xml', :provider_key => @provider_key,
                                         :app_id     => @application.id,
                                         :usage      => {'hits' => 2}
         Resque.run!

         assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 100, 100)
         assert_not_authorized 'usage limits are exceeded'
       end

       10.times do |cont|
         get '/transactions/authrep.xml', :provider_key => @provider_key,
                                            :app_id     => @application.id,
                                            :usage      => {'hits' => "##{100 + (cont+1)*-2}"}
         Resque.run!

         assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), 'hits', 'day', 100 + (cont+1)*-2, 100)
         assert_authorized
       end
     end
  end

  test 'does not create stats keys when setting the usage to 0 (#0)' do
    hits_id = @metric_id
    current_time = Time.now

    Timecop.freeze(current_time) do
      get '/transactions/authrep.xml',
           provider_key: @provider_key,
           app_id: @application.id,
           usage: { 'hits' => '#0' }

      Resque.run!
    end

    stats_keys = app_keys_for_all_periods(@service_id, @application.id, hits_id, current_time)
    stats_keys_created = stats_keys.any? { |key| @storage.exists?(key) }
    assert_false stats_keys_created
  end

  test 'deletes existing stats keys when setting the usage to 0 (#0)' do
    hits_id = @metric_id
    current_time = Time.now

    # Report something to generate stats keys
    Timecop.freeze(current_time) do
      get '/transactions/authrep.xml',
          provider_key: @provider_key,
          app_id: @application.id,
          usage: { 'hits' => 10 }

      Resque.run!
    end

    Timecop.freeze(current_time) do
      get '/transactions/authrep.xml',
          provider_key: @provider_key,
          app_id: @application.id,
          usage: { 'hits' => '#0' }

      Resque.run!
    end

    stats_keys = app_keys_for_all_periods(@service_id, @application.id, hits_id, current_time)
    stats_keys_created = stats_keys.any? { |key| @storage.exists?(key) }
    assert_false stats_keys_created
  end
end
