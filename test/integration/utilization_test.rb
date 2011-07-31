require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class StatusSnapshotTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::StorageKeys

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!

    setup_provider_fixtures

    @application_id1 = next_id

    Application.save(:service_id => @service.id,
                      :id         => @application_id1,
                      :state      => :active,
                      :plan_id    => @plan_id,
                      :plan_name  => @plan_name)

    @hits_id = next_id
    Metric.save(:service_id => @service.id, :id => @hits_id, :name => 'hits')
    @foos_id
    Metric.save(:service_id => @service.id, :id => @foos_id, :name => 'foos')

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @hits_id,
                    :month        => 1000)

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @hits_id,
                    :day        => 100)

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @foos_id,
                    :month        => 500)

  end

  test 'basic working of status_snapshot' do

    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id => @application_id1, :usage => {'hits' => 50, 'foos' => 115}}}
    Resque.run!

    get "/services/#{@service_id}/applications/#{@application_id1}/utilization.xml", 
       :provider_key => @provider_key
                                                       
    assert_equal 200, last_response.status
    doc   = Nokogiri::XML(last_response.body)
    assert_equal doc.at('max_utilization')[:value], '50'
    assert_equal doc.search('usage_report').size, 3
    assert_equal doc.search('max_usage_report').size, 1

    get "/services/#{@service_id}/applications/fake_application_key/utilization.xml", 
       :provider_key => @provider_key
    assert_equal 404, last_response.status

    get "/services/fake_service_id/applications/#{@application_id1}/utilization.xml", 
       :provider_key => @provider_key
    assert_equal 404, last_response.status

  end

  test 'basic check of utilization stats' do

    Timecop.freeze(Time.utc(2010, 1, 1, 0, 0, 0)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application_id1, :usage => {'hits' => 50}}}
      Resque.run!

      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application_id1, :usage => {'hits' => 30}}}
      Resque.run!

      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application_id1, :usage => {'hits' => 10}}}
      Resque.run!

      get "/services/#{@service_id}/applications/#{@application_id1}/utilization.xml", 
       :provider_key => @provider_key
                                                       
      assert_equal 200, last_response.status
      doc   = Nokogiri::XML(last_response.body)
      assert_equal doc.at('max_utilization')[:value], '90'    
    end    

    Timecop.freeze(Time.utc(2010, 1, 3, 15, 0 ,0)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application_id1, :usage => {'hits' => 50}}}
      Resque.run!

      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application_id1, :usage => {'hits' => 30}}}
      Resque.run!


      get "/services/#{@service_id}/applications/#{@application_id1}/utilization.xml", 
       :provider_key => @provider_key
                                                       
      assert_equal 200, last_response.status
      doc   = Nokogiri::XML(last_response.body)
      assert_equal doc.at('max_utilization')[:value], '80'    
    end    

    Timecop.freeze(Time.utc(2010, 1, 6, 15, 0, 0)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application_id1, :usage => {'hits' => 50}}}
      Resque.run!

      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application_id1, :usage => {'hits' => 60}}}
      Resque.run!


      get "/services/#{@service_id}/applications/#{@application_id1}/utilization.xml", 
       :provider_key => @provider_key                                                       
      assert_equal 200, last_response.status
      doc   = Nokogiri::XML(last_response.body)
      assert_equal doc.at('max_utilization')[:value], '110'
    end    

    Timecop.freeze(Time.utc(2010, 1, 6, 15, 55, 0)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application_id1, :usage => {'hits' => 100}}}
      Resque.run!

      get "/services/#{@service_id}/applications/#{@application_id1}/utilization.xml", 
       :provider_key => @provider_key                                                       
      assert_equal 200, last_response.status
      doc   = Nokogiri::XML(last_response.body)
      assert_equal doc.at('max_utilization')[:value], '210'
      
    end    

    Timecop.freeze(Time.utc(2010, 1, 7, 0, 0, 45)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application_id1, :usage => {'hits' => 0}}}
      Resque.run!

      get "/services/#{@service_id}/applications/#{@application_id1}/utilization.xml", 
       :provider_key => @provider_key                                                       
      assert_equal 200, last_response.status
      doc   = Nokogiri::XML(last_response.body)
     
      assert_equal doc.at('max_utilization')[:value], '38'
      ## the 38 comes out of 380 of 1000 per month
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application_id1, :usage => {'hits' => 50}}}
      Resque.run!

      get "/services/#{@service_id}/applications/#{@application_id1}/utilization.xml", 
       :provider_key => @provider_key                                                       
      assert_equal 200, last_response.status
      doc   = Nokogiri::XML(last_response.body)
      assert_equal doc.at('max_utilization')[:value], '50'
     
      assert_not_nil doc.at('stats').to_xml

      expected = "<stats>\n    <data time=\"2010-01-01 00:00:00 UTC\" value=\"90\"/>\n    <data time=\"2010-01-03 15:00:00 UTC\" value=\"80\"/>\n    <data time=\"2010-01-06 15:00:00 UTC\" value=\"210\"/>\n  </stats>"

      assert_equal expected, doc.at('stats').to_xml.to_s
   
    end    

  end 

end
