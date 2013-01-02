require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class BackgroundReportTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::StorageKeys
  include TestHelpers::Errors


  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!
    Memoizer.reset!
    
    setup_provider_fixtures_multiple_services

    @application_1 = Application.save(:service_id => @service_1.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id_1,
                                    :plan_name  => @plan_name_1)

    @application_2 = Application.save(:service_id => @service_2.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id_2,
                                    :plan_name  => @plan_name_2)

    @application_3 = Application.save(:service_id => @service_3.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id_3,
                                    :plan_name  => @plan_name_3)


    @metric_id_1 = next_id
    Metric.save(:service_id => @service_1.id, :id => @metric_id_1, :name => 'hits')

    @metric_id_2 = next_id
    Metric.save(:service_id => @service_2.id, :id => @metric_id_2, :name => 'hits')

    @metric_id_3 = next_id
    Metric.save(:service_id => @service_3.id, :id => @metric_id_3, :name => 'hits')

    UsageLimit.save(:service_id => @service_1.id,
                    :plan_id    => @plan_id_1,
                    :metric_id  => @metric_id_1,
                    :day => 100)

    UsageLimit.save(:service_id => @service_2.id,
                    :plan_id    => @plan_id_2,
                    :metric_id  => @metric_id_2,
                    :day => 100)

    UsageLimit.save(:service_id => @service_3.id,
                    :plan_id    => @plan_id_3,
                    :metric_id  => @metric_id_3,
                    :day => 100)

  end

  test 'fails when sending user_id when service does not support user plans' do

    post '/transactions.xml',
      :provider_key => @provider_key,
      :service_id   => @service_1.id,  
      :transactions => {0 => {:app_id => @application_1.id, :usage => {'hits' => 3}}}
    assert_equal 202, last_response.status
    Resque.run!

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application_1.id,
                                       :service_id   => @service_1.id

    assert_equal 200, last_response.status
    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_not_nil day
    assert_equal '3', day.at('current_value').content

    post '/transactions.xml',
      :provider_key => @provider_key,
      :service_id   => @service_1.id,  
      :transactions => {0 => {:user_id => "user_id1", :app_id => @application_1.id, :usage => {'hits' => 3}}}
    assert_equal 202, last_response.status
    Resque.run!

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application_1.id,
                                       :service_id   => @service_1.id,
                                       
    assert_equal 200, last_response.status
    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_not_nil day
    assert_equal '6', day.at('current_value').content

        
    

  end


end
