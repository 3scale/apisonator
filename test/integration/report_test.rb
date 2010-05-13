require File.dirname(__FILE__) + '/../test_helper'

class ReportTest < Test::Unit::TestCase
  include TestHelpers::Integration
  include TestHelpers::MasterService

  def setup
    @storage = ThreeScale::Backend.storage
    @storage.flushdb

    setup_master_service

    @master_contract_id = next_id
    @provider_key = 'provider_key'
    Contract.save(:service_id => @master_service_id, :user_key => @provider_key,
                  :id => @master_contract_id, :state => :live)

    @service_id = next_id
    Service.save(:provider_key => @provider_key, :id => @service_id)

    @contract_id = next_id
    @user_key = 'user_key'
    Contract.save(:service_id => @service_id, :id => @contract_id,
                  :user_key => @user_key, :state => :live)

    @metric_id = next_id
    Metrics.save(:service_id => @service_id, @metric_id => {:name => 'hits'})
  end

  def test_successful_report_responds_with_200
    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:user_key => @user_key, :usage => {'hits' => 1}}}

    assert_equal 200, last_response.status
  end
  
  def test_successful_report_increments_the_stats_counters
    Timecop.freeze(Time.utc(2010, 5, 10, 17, 36)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:user_key => @user_key, :usage => {'hits' => 1}}}

      key_month = contract_key(@service_id, @contract_id, @metric_id, :month, '20100501')
      key_day   = contract_key(@service_id, @contract_id, @metric_id, :day,   '20100510')
      key_hour  = contract_key(@service_id, @contract_id, @metric_id, :hour,  '2010051017')

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
        :transactions => {0 => {:user_key => @user_key, :usage => {'hits' => 1}}}

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
      :transactions => {0 => {:user_key  => @user_key,
                              :usage     => {'hits' => 1},
         
                              :timestamp => '2010-05-11 13:34:42'}}

    key = service_key(@service_id, @metric_id, :hour, '2010051113')
    assert_equal 1, @storage.get(key).to_i
  end
  
  def test_successful_report_with_local_timestamped_transactions
    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:user_key  => @user_key,
                              :usage     => {'hits' => 1},
                              :timestamp => '2010-05-11 11:08:25 -02:00'}}

    key = service_key(@service_id, @metric_id, :hour, '2010051113')
    assert_equal 1, @storage.get(key).to_i
  end
  
  def test_report_fails_on_invalid_provider_key
    post '/transactions.xml',
      :provider_key => 'boo',
      :transactions => {0 => {:user_key => @user_key, :usage => {'hits' => 1}}}

    assert_equal 'application/xml', last_response.headers['Content-Type']
    
    doc = Nokogiri::XML(last_response.body)

    assert_equal 1, doc.search('errors:root error').count
    node = doc.at('errors:root error')

    assert_not_nil node
    assert_equal 'provider.invalid_key', node['code']
    assert_equal 'provider authentication key is invalid', node.content
  end

  def test_report_fails_on_invalid_user_key
    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:user_key => 'boo', :usage => {'hits' => 1}}}

    assert_equal 'application/xml', last_response.headers['Content-Type']
    
    doc = Nokogiri::XML(last_response.body)
    node = doc.at('errors:root error[index = "0"]')

    assert_not_nil node
    assert_equal 'user.invalid_key', node['code']
    assert_equal 'user_key is invalid', node.content
  end
  
  def test_report_fails_on_invalid_metric_name
    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:user_key => @user_key, :usage => {'nukes' => 1}}}

    assert_equal 'application/xml', last_response.headers['Content-Type']
    
    doc = Nokogiri::XML(last_response.body)
    node = doc.at('errors:root error[index = "0"]')

    assert_not_nil node
    assert_equal 'provider.invalid_metric', node['code']
    assert_equal 'metric does not exist', node.content
  end
  
  def test_report_fails_on_invalid_usage_value
    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:user_key => @user_key, :usage => {'hits' => 'tons!'}}}

    assert_equal 'application/xml', last_response.headers['Content-Type']
    
    doc = Nokogiri::XML(last_response.body)
    node = doc.at('errors:root error[index = "0"]')

    assert_not_nil node
    assert_equal 'provider.invalid_usage_value', node['code']
    assert_equal 'usage value is invalid', node.content
  end

  def test_successful_report_reports_backend_hit
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:user_key => @user_key, :usage => {'hits' => 1}}}

      assert_equal 1, @storage.get(contract_key(@master_service_id,
                                                @master_contract_id,
                                                @master_hits_id,
                                               :month, '20100501')).to_i

      assert_equal 1, @storage.get(contract_key(@master_service_id,
                                                @master_contract_id,
                                                @master_reports_id,
                                               :month, '20100501')).to_i
    end
  end
  
  def test_successful_report_reports_number_of_transactions
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:user_key => @user_key, :usage => {'hits' => 1}},
                          1 => {:user_key => @user_key, :usage => {'hits' => 1}},
                          2 => {:user_key => @user_key, :usage => {'hits' => 1}}}

      assert_equal 3, @storage.get(contract_key(@master_service_id,
                                                @master_contract_id,
                                                @master_transactions_id,
                                                :month, '20100501')).to_i
    end
  end
    
  private

  def contract_key(service_id, contract_id, metric_id, period, time)
    "stats/{service:#{service_id}}/cinstance:#{contract_id}/metric:#{metric_id}/#{period}:#{time}"
  end
  
  def service_key(service_id, metric_id, period, time)
    "stats/{service:#{service_id}}/metric:#{metric_id}/#{period}:#{time}"
  end
end
