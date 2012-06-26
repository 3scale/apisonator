require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class Kkk < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration

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
  
  
  test 'check behabour of negatives on usage passed as parameter of authorize' do
    
    Timecop.freeze(Time.utc(2011, 1, 1)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 101}}}
      Resque.run!
    
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :usage      => {'hits' => -2}
                                    
      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "day", 101, 100)
      
      assert_authorized()
      
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application.id,
                                       :usage      => {'hits' => -2}
                                    
      assert_usage_report(Time.utc(2011, 1, 1, 13, 0, 0), "hits", "day", 101, 100)
      assert_authorized()
      
    end
                 
  end

end


