require File.dirname(__FILE__) + '/../test_helper'

class AuthorizeTest < Test::Unit::TestCase
  include TestHelpers::Integration
  include TestHelpers::MasterService
  include TestHelpers::StorageKeys
  
  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!

    setup_master_service

    @master_plan_id = next_id
    @provider_key = 'provider_key'
    Application.save(:service_id => @master_service_id, 
                     :id => @provider_key, 
                     :state => :active,
                     :plan_id => @master_plan_id)

    @service_id = next_id
    Core::Service.save(:provider_key => @provider_key, :id => @service_id)

    @application_id = next_id
    @plan_id = next_id
    @plan_name = 'kickass'
    Application.save(:service_id => @service_id, 
                     :id         => @application_id,
                     :state      => :active, 
                     :plan_id    => @plan_id, 
                     :plan_name  => @plan_name)

    @metric_id = next_id
    Metric.save(:service_id => @service_id, :id => @metric_id, :name => 'hits')
  end
    
  def test_successful_authorize_responds_with_200
    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application_id

    assert_equal 200, last_response.status
  end

  def test_response_of_successful_authorize_has_custom_content_type
    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application_id
    
    assert_equal 'application/vnd.3scale-v1.1+xml', last_response.content_type
  end

  def test_response_of_successful_authorize_contains_plan_name
    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application_id

    doc = Nokogiri::XML(last_response.body)
    assert_equal @plan_name, doc.at('status:root plan').content
  end

  def test_response_of_successful_authorize_contains_authorized_flag_set_to_true
    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application_id

    doc = Nokogiri::XML(last_response.body)
    assert_equal 'true', doc.at('status:root authorized').content
  end

  def test_response_of_successful_authorize_contains_usage_reports_if_the_plan_has_usage_limits
    UsageLimit.save(:service_id => @service_id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day => 100, :month => 10000)

    Timecop.freeze(Time.utc(2010, 5, 14)) do
      Transactor.report(@provider_key,
                        0 => {'app_id' => @application_id, 'usage' => {'hits' => 3}})
      Resque.run!
    end

    Timecop.freeze(Time.utc(2010, 5, 15)) do
      Transactor.report(@provider_key,
                        0 => {'app_id' => @application_id, 'usage' => {'hits' => 2}})
      Resque.run!
    end

    Timecop.freeze(Time.utc(2010, 5, 15)) do
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id     => @application_id

      doc = Nokogiri::XML(last_response.body)
      
      usage_reports = doc.at('usage_reports')
      assert_not_nil usage_reports
      
      day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
      assert_not_nil day
      assert_equal '2010-05-15 00:00:00 +0000', day.at('period_start').content
      assert_equal '2010-05-16 00:00:00 +0000', day.at('period_end').content
      assert_equal '2',                         day.at('current_value').content
      assert_equal '100',                       day.at('max_value').content
      
      month = usage_reports.at('usage_report[metric = "hits"][period = "month"]')
      assert_not_nil month
      assert_equal '2010-05-01 00:00:00 +0000', month.at('period_start').content
      assert_equal '2010-06-01 00:00:00 +0000', month.at('period_end').content
      assert_equal '5',                         month.at('current_value').content
      assert_equal '10000',                     month.at('max_value').content
    end
  end

  def test_response_of_successful_authorize_does_not_contain_usage_reports_if_the_plan_has_no_usage_limits
    Timecop.freeze(Time.utc(2010, 5, 15)) do
      Transactor.report(@provider_key,
                        0 => {'app_id' => @application_id, 'usage' => {'hits' => 2}})

      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id     => @application_id

      doc = Nokogiri::XML(last_response.body)
      
      assert_nil doc.at('usage_reports')
    end
  end

  def test_fails_on_invalid_provider_key
    get '/transactions/authorize.xml', :provider_key => 'boo',
                                       :app_id     => @application_id

    assert_error_response :code    => 'provider_key_invalid',
                          :message => 'provider key "boo" is invalid'
  end

  def test_fails_on_invalid_application_id
    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => 'boo'


    assert_error_response :status  => 404,
                          :code    => 'application_not_found',
                          :message => 'application with id="boo" was not found'
  end

  def test_does_not_authorize_on_inactive_application
    application = Application.load(@service_id, @application_id)
    application.state = :suspended
    application.save

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application_id

    assert_equal 200,                               last_response.status
    assert_equal 'application/vnd.3scale-v1.1+xml', last_response.content_type
    
    doc = Nokogiri::XML(last_response.body)
    assert_equal 'false', doc.at('status authorized').content
    assert_equal 'application is not active', doc.at('status reason').content
  end

  def test_does_not_authorize_on_exceeded_client_usage_limits
    UsageLimit.save(:service_id => @service_id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day => 4)

    Transactor.report(@provider_key,
                      0 => {'app_id' => @application_id, 'usage' => {'hits' => 5}})

    Resque.run!

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id     => @application_id

    assert_equal 200,                               last_response.status
    assert_equal 'application/vnd.3scale-v1.1+xml', last_response.content_type
    
    doc = Nokogiri::XML(last_response.body)
    assert_equal 'false', doc.at('status authorized').content
    assert_equal 'usage limits are exceeded', doc.at('status reason').content
  end

  def test_response_contains_usage_reports_marked_as_exceeded_on_exceeded_client_usage_limits
    UsageLimit.save(:service_id => @service_id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :month => 10, :day => 4)
    
    Transactor.report(@provider_key,
                      0 => {'app_id' => @application_id, 'usage' => {'hits' => 5}})

    Resque.run!

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application_id

    doc   = Nokogiri::XML(last_response.body)
    day   = doc.at('usage_report[metric = "hits"][period = "day"]')
    month = doc.at('usage_report[metric = "hits"][period = "month"]')

    assert_equal 'true', day['exceeded']
    assert_nil           month['exceeded']
  end

  def test_succeeds_if_no_application_key_is_defined_nor_passed
    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application_id

    assert_equal 200, last_response.status
    
    doc = Nokogiri::XML(last_response.body)
    assert_equal 'true', doc.at('status authorized').content
  end
  
  def test_succeeds_if_one_application_key_is_defined_and_the_same_one_is_passed
    application = Application.load(@service_id, @application_id)
    application_key = application.create_key!

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application_id,
                                       :app_key      => application_key

    assert_equal 200, last_response.status
    
    doc = Nokogiri::XML(last_response.body)
    assert_equal 'true', doc.at('status authorized').content
  end
  
  def test_succeeds_if_multiple_application_keys_are_defined_and_one_of_them_is_passed
    application = Application.load(@service_id, @application_id)
    application_key_one = application.create_key!
    application_key_two = application.create_key!

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application_id,
                                       :app_key      => application_key_one

    assert_equal 200, last_response.status
    
    doc = Nokogiri::XML(last_response.body)
    assert_equal 'true', doc.at('status authorized').content
  end

  def test_does_not_authorize_if_application_key_is_defined_but_not_passed
    application = Application.load(@service_id, @application_id)
    application.create_key!

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application_id

    assert_equal 200, last_response.status
    
    doc = Nokogiri::XML(last_response.body)
    assert_equal 'false',                      doc.at('status authorized').content
    assert_equal 'application key is missing', doc.at('status reason').content
  end
  
  def test_does_not_authorize_if_application_key_is_defined_but_wrong_one_is_passed
    application = Application.load(@service_id, @application_id)
    application.create_key!('foo')

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application_id,
                                       :app_key      => 'bar'

    assert_equal 200, last_response.status
    
    doc = Nokogiri::XML(last_response.body)
    assert_equal 'false',                            doc.at('status authorized').content
    assert_equal 'application key "bar" is invalid', doc.at('status reason').content
  end
  
  def test_succeeds_on_exceeded_provider_usage_limits
    UsageLimit.save(:service_id => @master_service_id,
                    :plan_id    => @master_plan_id,
                    :metric_id  => @master_hits_id,
                    :day        => 2)

    3.times do
      Transactor.report(@provider_key,
                        0 => {'app_id' => @application_id, 'usage' => {'hits' => 1}})
    end

    Resque.run!

    get '/transactions/authorize.xml', :provider_key => @provider_key,
                                       :app_id       => @application_id

    assert_equal 200,                               last_response.status
    assert_equal 'application/vnd.3scale-v1.1+xml', last_response.content_type
  end

  def test_successful_authorize_reports_backend_hit
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id       => @application_id

      Resque.run!

      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_key,
                                                   @master_hits_id,
                                                   :month, '20100501')).to_i

      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_key,
                                                   @master_authorizes_id,
                                                   :month, '20100501')).to_i
    end
  end

  def test_authorize_with_invalid_provider_key_does_not_report_backend_hit
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      get '/transactions/authorize.xml', :provider_key => 'boo',
                                         :app_id       => @application_id

      Resque.run!

      assert_equal 0, @storage.get(application_key(@master_service_id,
                                                   @provider_key,
                                                   @master_authorizes_id,
                                                   :month, '20100501')).to_i
    end
  end

  def test_authorize_with_invalid_application_id_reports_backend_hit
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id       => 'baa'

      Resque.run!

      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_key,
                                                   @master_authorizes_id,
                                                   :month, '20100501')).to_i
    end
  end

  def test_authorize_with_inactive_application_reports_backend_hit
    application = Application.load(@service_id, @application_id)
    application.state = :suspended
    application.save

    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id       => @application_id

      Resque.run!

      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_key,
                                                   @master_authorizes_id,
                                                   :month, '20100501')).to_i
    end
  end

  def test_authorize_with_exceeded_usage_limits_reports_backend_hit
    UsageLimit.save(:service_id => @service_id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day        => 4)

    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      Transactor.report(@provider_key,
                        0 => {'app_id' => @application_id, 'usage' => {'hits' => 5}})
      Resque.run!
    end


    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id       => @application_id

      Resque.run!

      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_key,
                                                   @master_authorizes_id,
                                                   :month, '20100501')).to_i
    end
  end

  def test_authorize_archives_backend_hit
    path = configuration.archiver.path
    FileUtils.rm_rf(path)

    Timecop.freeze(Time.utc(2010, 5, 11, 11, 54)) do
      get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id       => @application_id
      
      Resque.run!

      content = File.read("#{path}/service-#{@master_service_id}/20100511.xml.part")
      content = "<transactions>#{content}</transactions>"

      doc = Nokogiri::XML(content)
      node = doc.at('transaction')

      assert_not_nil node
      assert_equal '2010-05-11 11:54:00', node.at('timestamp').content
      assert_equal '1', node.at("values value[metric_id = \"#{@master_hits_id}\"]").content
      assert_equal '1', node.at("values value[metric_id = \"#{@master_authorizes_id}\"]").content
    end
  end
end
