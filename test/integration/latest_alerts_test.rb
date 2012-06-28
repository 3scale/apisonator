require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class LatestAlertsTest < Test::Unit::TestCase
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::StorageKeys
  include Backend::Alerts

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!

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

  test 'test empty responses' do 

    
    get "/services/#{@service_id}/alerts.xml",   :provider_key => @provider_key
                                
    assert_equal 200, last_response.status
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 1, doc.search('alerts').size
    assert_equal 0, doc.search('alert').size

 
  end

  test 'test errors on the paramters' do 

    get "/services/#{@service_id}/alerts.xml",       :provider_key => "fake_provider_key"                 
    doc   = Nokogiri::XML(last_response.body)
    error = doc.at('error:root')
    assert_not_nil error
    assert_equal 'provider_key_invalid', error['code']
    assert_equal 403, last_response.status

    get "/services/fake_service_id/alerts.xml",       :provider_key => @provider_key             
    doc   = Nokogiri::XML(last_response.body)
    error = doc.at('error:root')
    assert_not_nil error
    assert_equal 'provider_key_invalid', error['code']
    assert_equal 403, last_response.status

    get "/services/#{@service_id}/alerts.xml",       :provider_key => @provider_key
                                   
    assert_equal 200, last_response.status
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 1, doc.search('alerts').size
    assert_equal 0, doc.search('alert').size

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

  test 'test correct results for alerts with authrep' do 

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

      
    get "/services/#{@service_id}/alerts.xml",       :provider_key => @provider_key
                                   
    assert_equal 200, last_response.status
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 1, doc.search('alerts').size
    assert_equal 4, doc.search('alert').size

    alert = doc.xpath("//alert[@application_id='#{@application_id3}']").first

    assert_equal @service_id, alert.attributes["service_id"].content
    assert_equal @application_id3, alert.attributes["application_id"].content
    assert_equal "80", alert.attributes["utilization"].content
    assert_equal "foos per month: 81/100", alert.attributes["limit"].content
    assert_not_nil alert.attributes["timestamp"].content
    assert_not_nil alert.attributes["id"].content

  end




  test 'test alerts with authrep' do

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                      :app_id       => @application_id1,
                                      :usage        => {'foos' => 99}
    Resque.run!

    get "/services/#{@service_id}/alerts.xml",       :provider_key => @provider_key
                            
    assert_equal 200, last_response.status
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 1, doc.search('alerts').size
    assert_equal 1, doc.search('alert').size

    get "/services/#{@service_id}/alerts.xml",       :provider_key => @provider_key

    assert_equal 200, last_response.status
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 1, doc.search('alerts').size
    assert_equal 0, doc.search('alert').size


    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                      :app_id       => @application_id2,
                                      :usage        => {'foos' => 99}
    Resque.run!
    assert_equal 200, last_response.status


    get "/services/#{@service_id}/alerts.xml",       :provider_key => @provider_key
                               
    assert_equal 200, last_response.status
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 1, doc.search('alerts').size
    assert_equal 1, doc.search('alert').size


    get "/services/#{@service_id}/alerts.xml",       :provider_key => @provider_key

    assert_equal 200, last_response.status
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 1, doc.search('alerts').size
    assert_equal 0, doc.search('alert').size

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                      :app_id       => @application_id1,
                                      :usage        => {'foos' => 1}
    Resque.run!
    assert_equal 200, last_response.status


    get "/services/#{@service_id}/alerts.xml",       :provider_key => @provider_key
                                                                   
    assert_equal 200, last_response.status
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 1, doc.search('alerts').size
    assert_equal 1, doc.search('alert').size

    get "/services/#{@service_id}/alerts.xml",       :provider_key => @provider_key
 
    assert_equal 200, last_response.status
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 1, doc.search('alerts').size
    assert_equal 0, doc.search('alert').size


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


    get "/services/#{@service_id}/alerts.xml",       :provider_key => @provider_key
                                                           
    assert_equal 200, last_response.status
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 1, doc.search('alerts').size
    assert_equal 4, doc.search('alert').size

    alert = doc.xpath("//alert[@application_id='#{@application_id3}']").first
    assert_equal @service_id, alert.attributes["service_id"].content
    assert_equal @application_id3, alert.attributes["application_id"].content
    assert_equal "100", alert.attributes["utilization"].content
    assert_equal "foos per month: 115/100", alert.attributes["limit"].content
    assert_not_nil alert.attributes["timestamp"].content
    assert_not_nil alert.attributes["id"].content
  end
end
