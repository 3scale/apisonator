require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class SetUserUsageTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!

    setup_provider_fixtures

    @default_user_plan_id = next_id
    @default_user_plan_name = "user plan mobile"

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

  test 'check behavior of set values on usage passed as parameter of authorize' do

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :user_id => "user1", :usage => {'hits' => "#99"}}}
      Resque.run!

      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :user_id => "user2", :usage => {'hits' => "#98"}}}
      Resque.run!

      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :user_id    => "user1",
                                       :usage      => {'hits' => 2}

      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "day", 99, 100)
      assert_not_authorized("usage limits are exceeded")

      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :user_id    => "user2",
                                       :usage      => {'hits' => 2}

      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "day", 98, 100)
      assert_authorized()

    end

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :user_id => "user1", :usage => {'hits' => 2}},
                          1 => {:app_id => @application.id, :user_id => "user2", :usage => {'hits' => 2}}}
      Resque.run!

      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :user_id     => "user1",
                                       :usage      => {'hits' => 2}

      doc = Nokogiri::XML(last_response.body)

      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "day", 101, 100)
      assert_not_authorized("usage limits are exceeded")

      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :user_id    => "user2",
                                       :usage      => {'hits' => 2}

      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "day", 100, 100)
      assert_not_authorized("usage limits are exceeded")

      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :user_id    => "user2"

      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "day", 100, 100)
      assert_authorized()

    end

    Timecop.freeze(Time.utc(2011, 1, 1)) do

      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :user_id      => "user1",
                                       :usage      => {'hits' => "#66"}

      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "day", 101, 100)
      assert_authorized()

      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :user_id      => "user2",
                                       :usage      => {'hits' => "#100"}

      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "day", 100, 100)
      assert_authorized()

    end

  end

  test 'check behaviour of set values with caching and authorize' do

     Timecop.freeze(Time.utc(2011, 1, 1)) do
       post '/transactions.xml',
         :provider_key => @provider_key,
         :transactions => {0 => {:app_id => @application.id, :user_id => "user1", :usage => {'hits' => 80}}}
       Resque.run!

       10.times do |cont|
         if cont%2==1
           get '/transactions/authorize.xml', :provider_key => @provider_key,
                                              :app_id     => @application.id,
                                              :user_id    => "user1",
                                              :usage      => {'hits' => "##{80 + (cont)*2}"}
           Resque.run!
         else
           get '/transactions/authorize.xml', :provider_key => @provider_key,
                                               :app_id     => @application.id,
                                               :user_id    => "user1",
                                               :usage      => {'hits' => 2}
           Resque.run!
         end

         assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "day", 80 + (cont)*2, 100)
         assert_authorized()

         post '/transactions.xml',
            :provider_key => @provider_key,
            :transactions => {0 => {:app_id => @application.id, :user_id => "user1", :usage => {'hits' => 2}}}
         Resque.run!

       end

       10.times do |cont|
         get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id     => @application.id,
                                         :user_id    => "user1",
                                         :usage      => {'hits' => 2}
         Resque.run!

         assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "day", 100, 100)
         assert_not_authorized("usage limits are exceeded")
       end

       10.times do |cont|
         get '/transactions/authorize.xml', :provider_key => @provider_key,
                                        :app_id     => @application.id,
                                        :user_id    => "user1",
                                        :usage      => {'hits' => "##{100 + (cont+1)*-2}"}

         assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "day", 100 + (cont)*-2, 100)
         assert_authorized()

         post '/transactions.xml',
             :provider_key => @provider_key,
             :transactions => {0 => {:app_id => @application.id, :user_id => "user1", :usage => {'hits' => "##{100 + (cont+1)*-2}"}}}
         Resque.run!
       end

     end
  end

end
