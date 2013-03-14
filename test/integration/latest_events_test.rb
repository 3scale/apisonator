require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class LatestEventsTest < Test::Unit::TestCase
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::StorageKeys
  include Backend::Alerts

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!
    Memoizer.reset!
    
    setup_provider_fixtures

    @application_id1 = next_id
    Application.save(:service_id => @service_id,
                     :id         => @application_id1,
                     :plan_id    => @plan_id,
                     :state      => :active)

    @application_id2 = next_id
    Application.save(:service_id => @service_id,
                     :id         => @application_id2,
                     :plan_id    => @plan_id,
                     :state      => :active)

    @application_id3 = next_id
    Application.save(:service_id => @service_id,
                     :id         => @application_id3,
                     :plan_id    => @plan_id,
                     :state      => :active)


    @foos_id = next_id
    Metric.save(:service_id => @service_id, :id => @foos_id, :name => 'foos')

    UsageLimit.save(:service_id => @service_id,
                    :plan_id    => @plan_id,
                    :metric_id  => @foos_id,
                    :month        => 100)

    Alerts::ALERT_BINS.each do |val|
      add_allowed_limit(@service_id, val)
    end

    

  end
  
  def filter_events_by_type(type)
    
    get "/events.json",                            :provider_key => @master_provider_key
    assert_equal 200, last_response.status
    obj = Yajl::Parser.parse(last_response.body)
    
    ## filter the non alert events
    obj.each do |item|
      if item['type']!=type
        delete "/events/#{item['id']}.json",       :provider_key => @master_provider_key
        assert_equal 200, last_response.status
        obj = Yajl::Parser.parse(last_response.body)
        assert_equal 1, obj
      end
    end
    
  end  

  test 'test empty responses' do 

    get "/services/#{@service_id}/alerts.xml",   :provider_key => @provider_key                  
    assert_equal 404, last_response.status
    
    get "/events.json",   :provider_key => @master_provider_key
    obj = Yajl::Parser.parse(last_response.body)
    assert_not_nil obj
    assert_equal [], obj
    assert_equal 200, last_response.status
     
  end

  test 'test errors on the parameters' do 

    get "/services/#{@service_id}/alerts.xml", :provider_key => "fake_provider_key"    
    assert_equal 404, last_response.status
                 
    get "/events.json", :provider_key => "fake_provider_key"
    assert_equal 403, last_response.status
    obj = Yajl::Parser.parse(last_response.body)
    assert_not_nil obj
    assert_equal 'provider_key_invalid', obj['error']['code']
    assert_equal "provider key \"fake_provider_key\" is invalid", obj['error']['message']
       
    delete "/events.json", :to_id => 9999999, :provider_key => "fake_provider_key"
    assert_equal 403, last_response.status
    obj = Yajl::Parser.parse(last_response.body)
    assert_not_nil obj
    assert_equal 'provider_key_invalid', obj['error']['code']
    assert_equal "provider key \"fake_provider_key\" is invalid", obj['error']['message']
    
    delete "/events/9999999.json", :provider_key => "fake_provider_key"
    assert_equal 403, last_response.status
    obj = Yajl::Parser.parse(last_response.body)
    assert_not_nil obj
    assert_equal 'provider_key_invalid', obj['error']['code']
    assert_equal "provider key \"fake_provider_key\" is invalid", obj['error']['message']
    
  end

  
  test 'adding removing alert_limits' do

    get "/services/#{@service_id}/alert_limits.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc   = Nokogiri::XML(last_response.body)                       

    assert_equal Alerts::ALERT_BINS.size, doc.search("limit").size

    doc.search("limit").each do |item|
      assert_equal true, Alerts::ALERT_BINS.member?(item.attributes["value"].content.to_i)
    end

    delete "/services/#{@service_id}/alert_limits/100.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status

    delete "/services/#{@service_id}/alert_limits/120.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status

    delete "/services/#{@service_id}/alert_limits/666.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status

    doc   = Nokogiri::XML(last_response.body)

    assert_equal Alerts::ALERT_BINS.size-2, doc.search("limit").size
    doc.search("limit").each do |item|
      assert_equal true, Alerts::ALERT_BINS.member?(item.attributes["value"].content.to_i) 
      
      assert_not_equal '100', item.attributes["value"].content
      assert_not_equal '120', item.attributes["value"].content
      assert_not_equal '666', item.attributes["value"].content

    end            

    post "/services/#{@service_id}/alert_limits/120.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status

    post "/services/#{@service_id}/alert_limits/999.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status

    doc   = Nokogiri::XML(last_response.body)

    assert_equal Alerts::ALERT_BINS.size-1, doc.search("limit").size
    doc.search("limit").each do |item|
      assert_equal true, Alerts::ALERT_BINS.member?(item.attributes["value"].content.to_i) 
      assert_not_equal '100', item.attributes["value"].content
      assert_not_equal '666', item.attributes["value"].content
      assert_not_equal '999', item.attributes["value"].content
    end            

  end

  test 'test correct results for first_traffic events with authrep' do
  
      get '/transactions/authrep.xml', :provider_key => @provider_key,
                                        :app_id       => @application_id1,
                                        :usage        => {'foos' => 1}
      Resque.run!
      ## processes all the pending notifyjobs that. This creates a NotifyJob with the 
      ## aggregate and another Resque.run! is needed
      Backend::Transactor.process_batch(0,{:all => true})
      Resque.run!
      
      ## 
      get "/events.json",       :provider_key => @master_provider_key
      assert_equal 200, last_response.status
      obj = Yajl::Parser.parse(last_response.body)
      
      ## two, one of the app, and one for the master app
      assert_equal 2, obj.size
      
      obj.each do |item|
        assert_equal item['type'], "first_traffic"
        assert_equal true, item['object']['service_id']==@service_id || item['object']['service_id']==@master_service_id    
      end
      
      delete "/events.json",       :to_id => 99999999, :provider_key => @master_provider_key
      assert_equal 200, last_response.status
      obj = Yajl::Parser.parse(last_response.body)
      assert_equal 2, obj
      
      get "/events.json",       :provider_key => @master_provider_key
      assert_equal 200, last_response.status
      obj = Yajl::Parser.parse(last_response.body)
      assert_equal [], obj
      
      get '/transactions/authrep.xml', :provider_key => @provider_key,
                                        :app_id       => @application_id2,
                                        :usage        => {'foos' => 1}
      Resque.run!

      get '/transactions/authrep.xml', :provider_key => @provider_key,
                                        :app_id       => @application_id3,
                                        :usage        => {'foos' => 1}
      Resque.run!
  
      get "/events.json",       :provider_key => @master_provider_key
      assert_equal 200, last_response.status
      obj = Yajl::Parser.parse(last_response.body)
      
      ## two, one of the app, and one for the master app
      assert_equal 2, obj.size
      
      obj.each do |item|
        assert_equal item['type'], "first_traffic"
        assert_equal true, item['object']['service_id']==@service_id 
        assert_equal true, (item['object']['application_id']==@application_id2 || item['object']['application_id']==@application_id3)    
      end
      
      delete "/events.json",       :to_id => 10000, :provider_key => @master_provider_key
      assert_equal 200, last_response.status
      obj = Yajl::Parser.parse(last_response.body)
      assert_equal 2, obj
      
      get "/events.json",       :provider_key => @master_provider_key
      assert_equal 200, last_response.status
      obj = Yajl::Parser.parse(last_response.body)
      assert_equal [], obj
      
      get '/transactions/authrep.xml', :provider_key => @provider_key,
                                        :app_id       => @application_id2,
                                        :usage        => {'foos' => 1}
      Resque.run!

      get '/transactions/authrep.xml', :provider_key => @provider_key,
                                        :app_id       => @application_id3,
                                        :usage        => {'foos' => 1}
      Resque.run!
      
      ## now it's empty because @application_id1, and @application_id2 first_traffic event already raised
            
      get "/events.json",       :provider_key => @master_provider_key
      assert_equal 200, last_response.status
      obj = Yajl::Parser.parse(last_response.body)
      assert_equal [], obj
      
      delete "/events.json",       :to_id => 10000, :provider_key => @master_provider_key
      assert_equal 200, last_response.status
      obj = Yajl::Parser.parse(last_response.body)
      assert_equal 0, obj
    
  end
  
  

  test 'test correct results for events with authrep' do 

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                      :app_id       => @application_id1,
                                      :usage        => {'foos' => 81}
    Resque.run!

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                      :app_id       => @application_id1,
                                      :usage        => {'foos' => 10}
    Resque.run!

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                      :app_id       => @application_id2,
                                      :usage        => {'foos' => 81}
    Resque.run!

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                      :app_id       => @application_id3,
                                      :usage        => {'foos' => 81}
    Resque.run!

    ## processes all the pending notifyjobs that. This creates a NotifyJob with the 
    ## aggregate and another Resque.run! is needed
    Backend::Transactor.process_batch(0,{:all => true})
    Resque.run!
 
    get "/events.json",       :provider_key => @master_provider_key
    assert_equal 200, last_response.status
    obj = Yajl::Parser.parse(last_response.body)
    assert_not_nil obj
    assert_equal 8, obj.size
    
    ## filter the non alert events
    obj.each do |item|
      if item['type']!='alert'
        delete "/events/#{item['id']}.json",       :provider_key => @master_provider_key
        assert_equal 200, last_response.status
        obj = Yajl::Parser.parse(last_response.body)
        assert_equal 1, obj
      end
    end
    
    get "/events.json",       :provider_key => @master_provider_key
    assert_equal 200, last_response.status
    obj = Yajl::Parser.parse(last_response.body)
    assert_not_nil obj
    assert_equal 4, obj.size
    
    obj.each do |item|
      assert_equal "alert", item['type']
    end
      
    saved_id = -1  
    obj.each do |item|
    
      if item['type']=='alert' && item['object']['application_id'].to_i==@application_id3.to_i
        saved_id = item['id']
        assert_equal @service_id.to_i, item['object']['service_id'].to_i
        assert_equal @application_id3.to_i, item['object']['application_id'].to_i
        assert_equal "80".to_i, item['object']['utilization'].to_i
        assert_equal "foos per month: 81/100", item['object']["limit"]
        assert_not_nil item['object']['timestamp']
        assert_not_nil item['object']['id']
        cont = 1
      end
      
    end
    
    assert_not_equal -1, saved_id
    
    delete "/events/#{saved_id}.json",       :provider_key => @master_provider_key
    assert_equal 200, last_response.status
    obj = Yajl::Parser.parse(last_response.body)
    assert_equal 1, obj
    
    get "/events.json",       :provider_key => @master_provider_key
    assert_equal 200, last_response.status
    obj = Yajl::Parser.parse(last_response.body)
    assert_not_nil obj
    assert_equal 3, obj.size
    
    obj.each do |item|
      assert_not_equal saved_id.to_i, item['id'].to_i
    end
    
        
  end


  test 'test alerts with authrep' do

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                      :app_id       => @application_id1,
                                      :usage        => {'foos' => 99}
    Resque.run!

    filter_events_by_type('alert')
    get "/events.json",                             :provider_key => @master_provider_key
    assert_equal 200, last_response.status
    obj = Yajl::Parser.parse(last_response.body)
    assert_equal 1, obj.size

    filter_events_by_type('alert')
    get "/events.json",                             :provider_key => @master_provider_key
    assert_equal 200, last_response.status
    obj = Yajl::Parser.parse(last_response.body)
    assert_equal 1, obj.size

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                      :app_id       => @application_id2,
                                      :usage        => {'foos' => 99}
    Resque.run!
    assert_equal 200, last_response.status


    filter_events_by_type('alert')
    get "/events.json",                             :provider_key => @master_provider_key
    assert_equal 200, last_response.status
    obj = Yajl::Parser.parse(last_response.body)
    assert_equal 2, obj.size


    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                      :app_id       => @application_id1,
                                      :usage        => {'foos' => 1}
    Resque.run!
    assert_equal 200, last_response.status

    filter_events_by_type('alert')
    get "/events.json",                             :provider_key => @master_provider_key
    assert_equal 200, last_response.status
    obj = Yajl::Parser.parse(last_response.body)
    assert_equal 3, obj.size

    filter_events_by_type('alert')
    get "/events.json",                             :provider_key => @master_provider_key
    assert_equal 200, last_response.status
    obj = Yajl::Parser.parse(last_response.body)
    assert_equal 3, obj.size

  end

  test 'test correct results for alerts with reports' do 

    ## alerts over 100% cannot happen on authrep

    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id => @application_id1, :usage => {'foos' => 115}}}
    Resque.run!

    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id => @application_id1, :usage => {'foos' => 10}}}
    Resque.run!

    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id => @application_id2, :usage => {'foos' => 115}}}    
    Resque.run!

    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id => @application_id3, :usage => {'foos' => 115}}}
    Resque.run!

    ## processes all the pending notifyjobs that. This creates a NotifyJob with the 
    ## aggregate and another Resque.run! is needed
    Backend::Transactor.process_batch(0,{:all => true})
    Resque.run!

    get "/events.json",                             :provider_key => @master_provider_key
    assert_equal 200, last_response.status
    obj = Yajl::Parser.parse(last_response.body)
    ## 4 alerts, 3 first_traffic for the apps, 1 first_traffic for master app
    assert_equal 4+1+3, obj.size
    
    filter_events_by_type('alert')
    
    get "/events.json",                             :provider_key => @master_provider_key
    assert_equal 200, last_response.status
    obj = Yajl::Parser.parse(last_response.body)
    assert_equal 4, obj.size   
    
    saved_id = -1  
    obj.each do |item|
      if item['type']=='alert' && item['object']['application_id'].to_i==@application_id3.to_i
        saved_id = item['id']
        assert_equal @service_id.to_i, item['object']['service_id'].to_i
        assert_equal @application_id3.to_i, item['object']['application_id'].to_i
        assert_equal "100".to_i, item['object']['utilization'].to_i
        assert_equal "foos per month: 115/100", item['object']["limit"]
        assert_not_nil item['object']['timestamp']
        assert_not_nil item['object']['id']
        cont = 1
      end
    end
    
    assert_not_equal -1, saved_id
    
  end
  
    
  test 'events_hook is triggered on report' do
    
    saved_ttl = EventStorage::PING_TTL
    EventStorage.redef_without_warning("PING_TTL", 5)
    
    configuration.events_hook = "http://foobar.foobar"
    
    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id => @application_id1, :usage => {'foos' => 115}}}
    
    assert_raise NoMethodError do
      Resque.run!
    end
    
    configuration.events_hook = ""
    EventStorage.redef_without_warning("PING_TTL", saved_ttl)
    
  end
  
  test 'events_hook is triggered on authrep' do
    
    saved_ttl = EventStorage::PING_TTL
    EventStorage.redef_without_warning("PING_TTL", 5) 
    
    configuration.events_hook = "http://foobar.foobar" 
      
    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                    :app_id       => @application_id1,
                                    :usage        => {'foos' => 99}

    assert_equal 200, last_response.status

    assert_raise NoMethodError do 
      Resque.run!
    end
      
    configuration.events_hook = ""
    EventStorage.redef_without_warning("PING_TTL", saved_ttl)  
  
  end
  
end
