require File.expand_path(File.dirname(__FILE__) + '/../test_helper')


class CacheWithUsersTest < Test::Unit::TestCase
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
                                                                      
  end

  test 'test failure on cache: both usage_report and user_usage_report' do

    @metric_id = next_id
    Metric.save(:service_id => @service.id, :id => @metric_id, :name => 'hits')

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :year => 100)    

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @default_user_plan_id,
                    :metric_id  => @metric_id,
                    :day => 100, :month => 1000, :eternity => 10000)
    
    Timecop.freeze(Time.utc(2011, 1, 1)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :user_id => "user1", :usage => {'hits' => 50}}}
      Resque.run!
    
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :user_id    => "user1",
                                       :usage      => {'hits' => 2}
                     
      doc = Nokogiri::XML(last_response.body)
      d1 = doc.to_xml

      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "year", 50, 100)      
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "day", 50, 100)
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "month", 50, 1000)
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "eternity", 50, 10000)
      assert_authorized()
              
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :user_id    => "user1",
                                       :usage      => {'hits' => 2}
                     
      doc = Nokogiri::XML(last_response.body)
      d2 = doc.to_xml
   
      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "year", 50, 100)      
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "day", 50, 100)
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "month", 50, 1000)
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "eternity", 50, 10000)
      assert_authorized()
     
      assert_equal d1, d2
      
    end
  end


  test 'test failure on cache: user_usage_report only' do

    @metric_id = next_id
    Metric.save(:service_id => @service.id, :id => @metric_id, :name => 'hits')

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @default_user_plan_id,
                    :metric_id  => @metric_id,
                    :day => 100, :month => 1000, :eternity => 10000)    

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :user_id => "user1", :usage => {'hits' => 50}}}
      Resque.run!
    
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :user_id    => "user1",
                                       :usage      => {'hits' => 2}
                     
      doc = Nokogiri::XML(last_response.body)
      d1 = doc.to_xml      
      assert_not_usage_report
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "day", 50, 100)
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "month", 50, 1000)
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "eternity", 50, 10000)
      assert_authorized()
                  
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :user_id    => "user1",
                                       :usage      => {'hits' => 2}
                     
      doc = Nokogiri::XML(last_response.body)
      d2 = doc.to_xml
  
      assert_not_usage_report
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "day", 50, 100)
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "month", 50, 1000)
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "eternity", 50, 10000)
      assert_authorized()
      assert_equal d1, d2

    end
  end


  test 'test failure on cache: no usage_report or user_usage_report' do

    @metric_id = next_id
    Metric.save(:service_id => @service.id, :id => @metric_id, :name => 'hits')

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :user_id => "user1", :usage => {'hits' => 50}}}
      Resque.run!
    
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :user_id    => "user1",
                                       :usage      => {'hits' => 2}
                     
      doc = Nokogiri::XML(last_response.body)
      d1 = doc.to_xml      
      assert_not_usage_report
      assert_not_user_usage_report
      assert_authorized()
                  
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :user_id    => "user1",
                                       :usage      => {'hits' => 2}
                     
      doc = Nokogiri::XML(last_response.body)
      d2 = doc.to_xml
     
      assert_not_usage_report
      assert_not_user_usage_report
      assert_authorized()

      assert_equal d1, d2

    end
  end

 test 'test failure on cache: both usage_report and user_usage_report over limits' do

    @metric_id = next_id
    Metric.save(:service_id => @service.id, :id => @metric_id, :name => 'hits')

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :year => 100)    

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @default_user_plan_id,
                    :metric_id  => @metric_id,
                    :day => 100, :month => 1000, :eternity => 10000)
    
    Timecop.freeze(Time.utc(2011, 1, 1)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :user_id => "user1", :usage => {'hits' => 110}}}
      Resque.run!
    
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :user_id    => "user1",
                                       :usage      => {'hits' => 2}
                     
      doc = Nokogiri::XML(last_response.body)
      d1 = doc.to_xml

      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "year", 110, 100)      
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "day", 110, 100)
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "month", 110, 1000)
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "eternity", 110, 10000)
      assert_not_authorized()
              
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :user_id    => "user1",
                                       :usage      => {'hits' => 2}
                     
      doc = Nokogiri::XML(last_response.body)
      d2 = doc.to_xml
     
      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "year", 110, 100)      
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "day", 110, 100)
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "month", 110, 1000)
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "eternity", 110, 10000)
      assert_not_authorized("usage limits are exceeded")
     
      assert_equal d1, d2
      
    end
  end


  test 'test failure on cache: user_usage_report only over limits' do

    @metric_id = next_id
    Metric.save(:service_id => @service.id, :id => @metric_id, :name => 'hits')

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @default_user_plan_id,
                    :metric_id  => @metric_id,
                    :day => 100, :month => 1000, :eternity => 10000)    

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :user_id => "user1", :usage => {'hits' => 110}}}
      Resque.run!
    
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :user_id    => "user1",
                                       :usage      => {'hits' => 2}
                     
      doc = Nokogiri::XML(last_response.body)
      d1 = doc.to_xml      
      assert_not_usage_report
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "day", 110, 100)
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "month", 110, 1000)
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "eternity", 110, 10000)
      assert_not_authorized()
                  
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :user_id    => "user1",
                                       :usage      => {'hits' => 2}
                     
      doc = Nokogiri::XML(last_response.body)
      d2 = doc.to_xml
      
      assert_not_usage_report
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "day", 110, 100)
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "month", 110, 1000)
      assert_user_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "eternity", 110, 10000)
      assert_not_authorized("usage limits are exceeded")
      assert_equal d1, d2

    end
  end


  test 'test failure on cache: no usage_report or user_usage_report over limits' do

    @metric_id = next_id
    Metric.save(:service_id => @service.id, :id => @metric_id, :name => 'hits')

    Timecop.freeze(Time.utc(2011, 1, 1)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :user_id => "user1", :usage => {'hits' => 110}}}
      Resque.run!
    
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :user_id    => "user1",
                                       :usage      => {'hits' => 2}
                     
      doc = Nokogiri::XML(last_response.body)
      d1 = doc.to_xml      
      assert_not_usage_report
      assert_not_user_usage_report
      assert_authorized()
                  
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :user_id    => "user1",
                                       :usage      => {'hits' => 2}
                     
      doc = Nokogiri::XML(last_response.body)
      d2 = doc.to_xml
      
      assert_not_usage_report
      assert_not_user_usage_report
      assert_authorized()

      assert_equal d1, d2

    end
  end


end
