require File.dirname(__FILE__) + '/../test_helper'

class ReportTest < Test::Unit::TestCase
  include TestHelpers::Integration
  include TestHelpers::MasterService
  include TestHelpers::StorageKeys

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!

    setup_master_service

    @provider_key = 'provider_key'
    Application.save(:service_id => @master_service_id, 
                     :id         => @provider_key,
                     :state      => :active)

    @service_id = next_id
    Core::Service.save(:provider_key => @provider_key, :id => @service_id)

    @application_id = next_id
    @plan_id = next_id
    Application.save(:service_id => @service_id, 
                     :id         => @application_id,
                     :plan_id    => @plan_id, 
                     :state      => :active)

    @metric_id = next_id
    Metric.save(:service_id => @service_id, :id => @metric_id, :name => 'hits')
  end

  def test_successful_report_responds_with_200
    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id => @application_id, :usage => {'hits' => 1}}}

    assert_equal 200, last_response.status
  end

  def test_successful_report_increments_the_stats_counters
    Timecop.freeze(Time.utc(2010, 5, 10, 17, 36)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application_id, :usage => {'hits' => 1}}}
      
      Resque.run!

      key_month = application_key(@service_id, @application_id, @metric_id, :month, '20100501')
      key_day   = application_key(@service_id, @application_id, @metric_id, :day,   '20100510')
      key_hour  = application_key(@service_id, @application_id, @metric_id, :hour,  '2010051017')

      assert_equal 1, @storage.get(key_month).to_i
      assert_equal 1, @storage.get(key_day).to_i
      assert_equal 1, @storage.get(key_hour).to_i
    end
  end

  def test_successful_report_archives_the_transactions
    path = configuration.archiver.path
    FileUtils.rm_rf(path)

    Timecop.freeze(Time.utc(2010, 5, 11, 11, 54)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application_id, :usage => {'hits' => 1}}}
      
      Resque.run!

      content = File.read("#{path}/service-#{@service_id}/20100511.xml.part")
      content = "<transactions>#{content}</transactions>"

      doc = Nokogiri::XML(content)
      node = doc.at('transaction')

      assert_not_nil node
      assert_equal '2010-05-11 11:54:00', node.at('timestamp').content
      assert_equal '1', node.at("values value[metric_id = \"#{@metric_id}\"]").content
    end
  end
  
  def test_successful_report_with_utc_timestamped_transactions
    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id    => @application_id,
                              :usage     => {'hits' => 1},
                              :timestamp => '2010-05-11 13:34:42'}}

    Resque.run!

    key = service_key(@service_id, @metric_id, :hour, '2010051113')
    assert_equal 1, @storage.get(key).to_i
  end
  
  def test_successful_report_with_local_timestamped_transactions
    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id    => @application_id,
                              :usage     => {'hits' => 1},
                              :timestamp => '2010-05-11 11:08:25 -02:00'}}
    
    Resque.run!

    key = service_key(@service_id, @metric_id, :hour, '2010051113')
    assert_equal 1, @storage.get(key).to_i
  end

  def test_report_fails_on_invalid_provider_key
    post '/transactions.xml',
      :provider_key => 'boo',
      :transactions => {0 => {:app_id => @application_id, :usage => {'hits' => 1}}}

    assert_equal 'application/vnd.3scale-v1.1+xml', last_response.content_type
    
    doc = Nokogiri::XML(last_response.body)

    node = doc.at('error:root')

    assert_not_nil node
    assert_equal 'provider_key_invalid', node['code']
    assert_equal 'provider key "boo" is invalid', node.content
  end

  def test_report_reports_error_on_invalid_application_id
    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id => 'boo', :usage => {'hits' => 1}}}

    assert_equal 200, last_response.status

    Resque.run!

    error = ErrorReporter.all(@service_id).last

    assert_not_nil error
    assert_equal 'application_not_found', error[:code]
    assert_equal 'application with id="boo" was not found', error[:message]
  end
  
  def test_report_reports_error_on_invalid_metric_name
    post '/transactions.xml',
       :provider_key => @provider_key,
       :transactions => {0 => {:app_id => @application_id, :usage => {'nukes' => 1}}}

    assert_equal 200, last_response.status

    Resque.run!

    error = ErrorReporter.all(@service_id).last

    assert_not_nil error
    assert_equal 'metric_invalid', error[:code]
    assert_equal 'metric "nukes" is invalid', error[:message]
  end
  
  def test_report_reports_error_on_empty_usage_value
    post '/transactions.xml',
       :provider_key => @provider_key,
       :transactions => {0 => {:app_id => @application_id, :usage => {'hits' => ' '}}}

    assert_equal 200, last_response.status
    
    Resque.run!

    error = ErrorReporter.all(@service_id).last

    assert_not_nil error
    assert_equal 'usage_value_invalid', error[:code]
    assert_equal %Q(usage value for metric "hits" can't be empty), error[:message]
  end
  
  def test_report_reports_error_on_invalid_usage_value
    post '/transactions.xml',
       :provider_key => @provider_key,
       :transactions => {0 => {:app_id => @application_id, 
                               :usage  => {'hits' => 'tons!'}}}

    assert_equal 200, last_response.status
    
    Resque.run!

    error = ErrorReporter.all(@service_id).last

    assert_not_nil error
    assert_equal 'usage_value_invalid', error[:code]
    assert_equal 'usage value "tons!" for metric "hits" is invalid', error[:message]
  end

  def test_report_does_not_aggregate_anything_when_at_least_one_transaction_is_invalid
    post '/transactions.xml',
       :provider_key => @provider_key,
       :transactions => {0 => {:app_id => @application_id, :usage => {'hits' => 1}},
                         1 => {:app_id => 'boo',           :usage => {'hits' => 1}}}

    Resque.run!

    key = application_key(@service_id, @application_id, @metric_id, 
                          :month, Time.now.strftime('%Y%m01'))
    assert_nil @storage.get(key)
  end
  
  def test_report_does_not_archive_anything_when_at_least_one_transaction_is_invalid
    path = configuration.archiver.path
    FileUtils.rm_rf(path)

    Timecop.freeze(Time.utc(2010, 5, 11, 11, 54)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application_id, :usage => {'hits' => 1}},
                          1 => {:app_id => 'foo',     :usage => {'hits' => 1}}}
      
      Resque.run!

      assert !File.exists?("#{path}/service-#{@service_id}/20100511.xml.part")
    end
  end

  def test_report_succeeds_when_application_is_not_active
    application = Application.load(@service_id, @application_id)
    application.state = :suspended
    application.save

    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id => @application_id, :usage => {'hits' => 1}}}

    assert_equal 200, last_response.status
  end

  def test_report_succeeds_when_client_usage_limits_are_exceeded
    UsageLimit.save(:service_id => @service_id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :month      => 2)

    Transactor.report(@provider_key,
                      '0' => {'app_id' => @application_id, 'usage' => {'hits' => 2}})

    Resque.run!

    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id => @application_id, :usage => {'hits' => 1}}}

    assert_equal 200, last_response.status
      
    Resque.run!

    assert_equal 3, @storage.get(
      application_key(@service_id, @application_id, @metric_id, :month,
                      Time.now.getutc.beginning_of_cycle(:month).to_compact_s)).to_i
  end
  
  def test_report_succeeds_when_provider_usage_limits_are_exceeded
    UsageLimit.save(:service_id => @master_service_id,
                    :plan_id    => @master_plan_id,
                    :metric_id  => @master_hits_id,
                    :month      => 2)

    3.times do
      Transactor.report(@provider_key,
                        '0' => {'app_id' => @application_id, 'usage' => {'hits' => 1}})
    end

    Resque.run!

    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id => @application_id, :usage => {'hits' => 1}}}

    assert_equal 200, last_response.status
      
    Resque.run!

    assert_equal 4, @storage.get(
      application_key(@service_id, @application_id, @metric_id, :month,
                      Time.now.getutc.beginning_of_cycle(:month).to_compact_s)).to_i
  end


  def test_successful_report_aggregates_backend_hit
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application_id, :usage => {'hits' => 1}}}
      
      Resque.run!

      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_key,
                                                   @master_hits_id,
                                                   :month, '20100501')).to_i

      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_key,
                                                   @master_reports_id,
                                                   :month, '20100501')).to_i
    end
  end
  
  def test_successful_report_aggregates_number_of_transactions
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application_id, :usage => {'hits' => 1}},
                          1 => {:app_id => @application_id, :usage => {'hits' => 1}},
                          2 => {:app_id => @application_id, :usage => {'hits' => 1}}}

      Resque.run!

      assert_equal 3, @storage.get(application_key(@master_service_id,
                                                   @provider_key,
                                                   @master_transactions_id,
                                                   :month, '20100501')).to_i
    end
  end
  
  def test_successful_report_archives_backend_hit
    path = configuration.archiver.path
    FileUtils.rm_rf(path)

    Timecop.freeze(Time.utc(2010, 5, 11, 11, 54)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application_id, :usage => {'hits' => 1}},
                          1 => {:app_id => @application_id, :usage => {'hits' => 1}}}
      
      Resque.run!

      content = File.read("#{path}/service-#{@master_service_id}/20100511.xml.part")
      content = "<transactions>#{content}</transactions>"

      doc = Nokogiri::XML(content)
      node = doc.at('transaction')

      assert_not_nil node
      assert_equal '2010-05-11 11:54:00', node.at('timestamp').content
      assert_equal '1', node.at("values value[metric_id = \"#{@master_hits_id}\"]").content
      assert_equal '1', node.at("values value[metric_id = \"#{@master_reports_id}\"]").content
      assert_equal '2', node.at("values value[metric_id = \"#{@master_transactions_id}\"]").content
    end
  end
  
  def test_report_with_invalid_provider_key_does_not_report_backend_hit
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      post '/transactions.xml',
        :provider_key => 'boo',
        :transactions => {0 => {:app_id => @application_id, :usage => {'hits' => 1}}}

      assert_equal 0, @storage.get(application_key(@master_service_id,
                                                   @provider_key,
                                                   @master_reports_id,
                                                   :month, '20100501')).to_i
    end
  end
  
  def test_report_with_invalid_transaction_reports_backend_hit
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => 'baa', :usage => {'hits' => 1}}}
      
      Resque.run!

      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_key,
                                                   @master_reports_id,
                                                   :month, '20100501')).to_i
    end
  end
  
  def test_report_with_invalid_transaction_reports_number_of_all_transactions
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => 'baa',           :usage => {'hits' => 1}},
                          1 => {:app_id => @application_id, :usage => {'hits' => 1}}}
      
      Resque.run!

      assert_equal 2, @storage.get(application_key(@master_service_id,
                                                   @provider_key,
                                                   @master_transactions_id,
                                                   :month, '20100501')).to_i
    end
  end
end
