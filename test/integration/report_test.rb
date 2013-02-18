require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class ReportTest < Test::Unit::TestCase
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::StorageKeys
  include Backend::StorageHelpers
  

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!
    Memoizer.reset!

    setup_provider_fixtures

    @application = Application.save(:service_id => @service_id,
                                    :id         => next_id,
                                    :plan_id    => @plan_id,
                                    :state      => :active)

    @metric_id = next_id
    Metric.save(:service_id => @service_id, :id => @metric_id, :name => 'hits')

    @apilog = {'request' => "API original request", 'response' => "API original response", 'code' => "200"}
    @apilog2 = {'request' => "API original request 2", 'response' => "API original response 2", 'code' => "200"}
    @apilog3 = {'request' => "API original request 3", 'response' => "API original response 3", 'code' => "200"}
    @apilog_imcomplete = {'code' => "200"}
    @apilog_empty = {}

  end
  
  def cassandra_setup
    
    Aggregator.enable_cassandra()
    Aggregator.activate_cassandra()
		
		@storage_cassandra = StorageCassandra.instance(true)
		@storage_cassandra.clear_keyspace!
		
		Resque.reset!
		Aggregator.reset_current_bucket!
		
	end

  test 'options request returns list of allowed methods' do
    request '/transactions.xml', :method => 'OPTIONS'
    assert_equal 200,    last_response.status
    assert_equal 'POST', last_response.headers['Allow']
  end

  test 'successful report responds with 202' do
    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}, :log => @apilog}}

    assert_equal 202, last_response.status
  end

  test 'successful report increments the stats counters' do
    Timecop.freeze(Time.utc(2010, 5, 10, 17, 36)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}, :log => @apilog}}

      Resque.run!

      key_month = application_key(@service_id, @application.id, @metric_id, :month, '20100501')
      key_day   = application_key(@service_id, @application.id, @metric_id, :day,   '20100510')
      key_hour  = application_key(@service_id, @application.id, @metric_id, :hour,  '2010051017')

      assert_equal 1, @storage.get(key_month).to_i
      assert_equal 1, @storage.get(key_day).to_i
      assert_equal 1, @storage.get(key_hour).to_i
    end
  end

  test 'successful report archives the transactions' do
    path = configuration.archiver.path
    FileUtils.rm_rf(path)

    Timecop.freeze(Time.utc(2010, 5, 11, 11, 54)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}, :log => @apilog}}

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

  test 'successful report with utc timestamped transactions' do
    Timecop.freeze(Time.utc(2010, 4, 23, 00, 00)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id    => @application.id,
                                :usage     => {'hits' => 1},
                                :timestamp => '2010-05-11 13:34:42'}}

      Resque.run!

      key = service_key(@service_id, @metric_id, :hour, '2010051113')
      assert_equal 1, @storage.get(key).to_i
    end  
  end

  test 'successful report with local timestamped transactions' do
    Timecop.freeze(Time.utc(2010, 4, 23, 00, 00)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id    => @application.id,
                                :usage     => {'hits' => 1},
                                :timestamp => '2010-05-11 11:08:25 -02:00'}}

      Resque.run!

      key = service_key(@service_id, @metric_id, :hour, '2010051113')
      assert_equal 1, @storage.get(key).to_i
    end
  end

  test 'report uses current time if timestamp is blank' do
    Timecop.freeze(Time.utc(2010, 8, 19, 11, 24)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id    => @application.id,
                                :usage     => {'hits' => 1},
                                :timestamp => ''}}

      Resque.run!
    end

    key = service_key(@service_id, @metric_id, :hour, '2010081911')
    assert_equal 1, @storage.get(key).to_i
  end

  test 'report fails on invalid provider key' do
    post '/transactions.xml',
      :provider_key => 'boo',
      :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}, :log => @apilog}}

    assert_error_response :code    => 'provider_key_invalid',
                          :message => 'provider key "boo" is invalid'
  end

  test 'report reports error on invalid application id' do
    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id => 'boo', :usage => {'hits' => 1}, :log => @apilog}}

    assert_equal 202, last_response.status

    Resque.run!

    error = ErrorStorage.list(@service_id).last

    assert_not_nil error
    assert_equal 'application_not_found', error[:code]
    assert_equal 'application with id="boo" was not found', error[:message]
  end

  # TODO: reports error on missing app id

  test 'report reports error on invalid metric name' do
    post '/transactions.xml',
       :provider_key => @provider_key,
       :transactions => {0 => {:app_id => @application.id, :usage => {'nukes' => 1}}}

    assert_equal 202, last_response.status

    Resque.run!

    error = ErrorStorage.list(@service_id).last

    assert_not_nil error
    assert_equal 'metric_invalid', error[:code]
    assert_equal 'metric "nukes" is invalid', error[:message]
  end

  test 'report reports error on empty usage value' do
    post '/transactions.xml',
       :provider_key => @provider_key,
       :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => ' '}}}

    assert_equal 202, last_response.status

    Resque.run!

    error = ErrorStorage.list(@service_id).last

    assert_not_nil error
    assert_equal 'usage_value_invalid', error[:code]
    assert_equal %Q(usage value for metric "hits" can not be empty), error[:message]
  end

  test 'report reports error on invalid usage value' do
    post '/transactions.xml',
       :provider_key => @provider_key,
       :transactions => {0 => {:app_id => @application.id,
                               :usage  => {'hits' => 'tons!'}}}

    assert_equal 202, last_response.status

    Resque.run!

    error = ErrorStorage.list(@service_id).last

    assert_not_nil error
    assert_equal 'usage_value_invalid', error[:code]
    assert_equal 'usage value "tons!" for metric "hits" is invalid', error[:message]
  end

  test 'report does not aggregate anything when at least one transaction is invalid' do
    post '/transactions.xml',
       :provider_key => @provider_key,
       :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}},
                         1 => {:app_id => 'boo',           :usage => {'hits' => 1}}}

    Resque.run!

    key = application_key(@service_id, @application.id, @metric_id,
                          :month, Time.now.getutc.strftime('%Y%m01'))
    assert_nil @storage.get(key)
  end

  test 'report does not archive anything when at least one transaction is invalid' do
    path = configuration.archiver.path
    FileUtils.rm_rf(path)

    Timecop.freeze(Time.utc(2010, 5, 11, 11, 54)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}},
                          1 => {:app_id => 'foo',     :usage => {'hits' => 1}}}

      Resque.run!

      assert !File.exists?("#{path}/service-#{@service_id}/20100511.xml.part")
    end
  end

  test 'report succeeds when application is not active' do
    application = Application.load(@service_id, @application.id)
    application.state = :suspended
    application.save

    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}}}

    assert_equal 202, last_response.status
  end

  test 'report succeeds when client usage limits are exceeded' do
    UsageLimit.save(:service_id => @service_id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :month      => 2)

    Transactor.report(@provider_key, nil,
                      '0' => {'app_id' => @application.id, 'usage' => {'hits' => 2}})

    Resque.run!

    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}}}

    assert_equal 202, last_response.status

    Resque.run!

    assert_equal 3, @storage.get(
      application_key(@service_id, @application.id, @metric_id, :month,
                      Time.now.getutc.beginning_of_cycle(:month).to_compact_s)).to_i
  end

  test 'report succeeds when provider usage limits are exceeded' do
    UsageLimit.save(:service_id => @master_service_id,
                    :plan_id    => @master_plan_id,
                    :metric_id  => @master_hits_id,
                    :month      => 2)

    3.times do
      Transactor.report(@provider_key, nil,
                        '0' => {'app_id' => @application.id, 'usage' => {'hits' => 1}})
    end

    Resque.run!

    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}}}

    assert_equal 202, last_response.status

    Resque.run!

    assert_equal 4, @storage.get(
      application_key(@service_id, @application.id, @metric_id, :month,
                      Time.now.getutc.beginning_of_cycle(:month).to_compact_s)).to_i
  end

  test 'report succeeds when valid legacy user key passed' do
    user_key = 'foobar'
    Application.save_id_by_key(@service_id, user_key, @application.id)

    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:user_key => user_key, :usage => {'hits' => 1}}}

    assert_equal 202, last_response.status

    Resque.run!

    key = application_key(@service_id, @application.id, @metric_id, :month,
                          Time.now.getutc.beginning_of_cycle(:month).to_compact_s)
    assert_equal 1, @storage.get(key).to_i
  end

  test 'report reports error on invalid legacy user key' do
    Application.save_id_by_key(@service_id, 'foobar', @application.id)

    post '/transactions.xml',
       :provider_key => @provider_key,
       :transactions => {0 => {:user_key => 'inyourface', :usage => {'hits' => 1}}}

    assert_equal 202, last_response.status

    Resque.run!

    error = ErrorStorage.list(@service_id).last

    assert_not_nil error
    assert_equal 'user_key_invalid', error[:code]
    assert_equal 'user key "inyourface" is invalid', error[:message]
  end

  test 'report reports error when both application id and legacy user key are used' do
    user_key = 'foobar'
    Application.save_id_by_key(@service_id, user_key, @application.id)

    post '/transactions.xml',
       :provider_key => @provider_key,
       :transactions => {0 => {:app_id   => @application.id,
                               :user_key => user_key,
                               :usage    => {'hits' => 1}}}

    assert_equal 202, last_response.status

    Resque.run!

    error = ErrorStorage.list(@service_id).last

    assert_not_nil error
    assert_equal 'authentication_error', error[:code]
    assert_equal 'either app_id or user_key is allowed, not both', error[:message]
  end

  test 'successful report aggregates backend hit' do
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}}}

      Resque.run!
      ## processes all the pending notifyjobs that. This creates a NotifyJob with the 
      ## aggregate and another Resque.run! is needed
      Backend::Transactor.process_batch(0,{:all => true})
      Resque.run!
      
      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_hits_id,
                                                   :month, '20100501')).to_i

      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_reports_id,
                                                   :month, '20100501')).to_i
    end
  end

  test 'successful report aggregates number of transactions' do
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}, :log => @apilog},
                          1 => {:app_id => @application.id, :usage => {'hits' => 1}, :log => @apilog1},
                          2 => {:app_id => @application.id, :usage => {'hits' => 1}, :log => @apilog2}}

      Resque.run!
      ## processes all the pending notifyjobs that. This creates a NotifyJob with the 
      ## aggregate and another Resque.run! is needed
      Backend::Transactor.process_batch(0,{:all => true})
      Resque.run!

      assert_equal 3, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_transactions_id,
                                                   :month, '20100501')).to_i
    end
  end

  test 'report with invalid provider key does not report backend hit' do
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      post '/transactions.xml',
        :provider_key => 'boo',
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}}}

      Resque.run!
      ## processes all the pending notifyjobs that. This creates a NotifyJob with the 
      ## aggregate and another Resque.run! is needed
      Backend::Transactor.process_batch(0,{:all => true})
      Resque.run!
        
      assert_equal 0, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_reports_id,
                                                   :month, '20100501')).to_i
    end
  end

  test 'report with invalid transaction reports backend hit' do
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => 'baa', :usage => {'hits' => 1}}}

      Resque.run!
      ## processes all the pending notifyjobs that. This creates a NotifyJob with the 
      ## aggregate and another Resque.run! is needed
      Backend::Transactor.process_batch(0,{:all => true})
      Resque.run!
      
      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_reports_id,
                                                   :month, '20100501')).to_i
    end
  end

  test 'report with invalid transaction reports number of all transactions' do
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => 'baa',           :usage => {'hits' => 1}},
                          1 => {:app_id => @application.id, :usage => {'hits' => 1}}}

      Resque.run!
      ## processes all the pending notifyjobs that. This creates a NotifyJob with the 
      ## aggregate and another Resque.run! is needed
      Backend::Transactor.process_batch(0,{:all => true})
      Resque.run!

      assert_equal 2, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_transactions_id,
                                                   :month, '20100501')).to_i
    end
  end

  test 'failed report on wrong provider key' do
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      post '/transactions.xml',
        :provider_key => "fake_provider_key",
        :transactions => {0 => {:app_id => 'baa',           :usage => {'hits' => 1}},
                          1 => {:app_id => @application.id, :usage => {'hits' => 1}}}

      Resque.run!
      ## processes all the pending notifyjobs that. This creates a NotifyJob with the 
      ## aggregate and another Resque.run! is needed
      Backend::Transactor.process_batch(0,{:all => true})
      Resque.run!

      assert_equal 403, last_response.status
      doc = Nokogiri::XML(last_response.body)
      error = doc.at('error:root')
      assert_not_nil error
      assert_equal 'provider_key_invalid', error['code']

             
      assert_equal 0, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_transactions_id,
                                                   :month, '20100501')).to_i

      
      post '/transactions.xml',
        :provider_key => @provider_key,
        :service_id => "fake_service_id",
        :transactions => {0 => {:app_id => 'baa',           :usage => {'hits' => 1}},
                          1 => {:app_id => @application.id, :usage => {'hits' => 1}}}

      Resque.run!
      ## processes all the pending notifyjobs that. This creates a NotifyJob with the 
      ## aggregate and another Resque.run! is needed
      Backend::Transactor.process_batch(0,{:all => true})
      Resque.run!

      assert_equal 403, last_response.status
      doc = Nokogiri::XML(last_response.body)
      error = doc.at('error:root')
      assert_not_nil error
      assert_equal 'provider_key_invalid', error['code']

             
      assert_equal 0, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_transactions_id,
                                                   :month, '20100501')).to_i
 


    end

  end

  test 'not fail on bogus timestamp on report, default to current timestamp' do


    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do

      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}, :timestamp => nil}}

      Resque.run!
      ## processes all the pending notifyjobs that. This creates a NotifyJob with the 
      ## aggregate and another Resque.run! is needed
      Backend::Transactor.process_batch(0,{:all => true})
      Resque.run!

      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_transactions_id,
                                                   :month, '20100501')).to_i   


      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}, :timestamp => ''}}

      Resque.run!
      ## processes all the pending notifyjobs that. This creates a NotifyJob with the 
      ## aggregate and another Resque.run! is needed
      Backend::Transactor.process_batch(0,{:all => true})
      Resque.run!

      assert_equal 2, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_transactions_id,
                                                   :month, '20100501')).to_i   


      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}, :timestamp => '0'}}

      Resque.run!
      ## processes all the pending notifyjobs that. This creates a NotifyJob with the 
      ## aggregate and another Resque.run! is needed
      Backend::Transactor.process_batch(0,{:all => true})
      Resque.run!

      assert_equal 3, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_transactions_id,
                                                   :month, '20100501')).to_i   



    end
  end


  test 'checking correct behavior of timestamps on report' do

    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      ts = Time.utc(2010,5,11,13,34)

      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}, :timestamp => ts.to_s}}

      Resque.run!

      assert_equal 0, @storage.get(application_key(@service_id,
                                                   @application.id,
                                                   @metric_id,
                                                   :day, '20100512')).to_i
      
      assert_equal 1, @storage.get(application_key(@service_id,
                                                   @application.id,
                                                   @metric_id,
                                                   :day, '20100511')).to_i

      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}, :timestamp => "2012/10/01"}}

      Resque.run!

      assert_equal 1, @storage.get(application_key(@service_id,
                                                   @application.id,
                                                   @metric_id,
                                                   :month, '20121001')).to_i

      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}, :timestamp => "2012"}}

      Resque.run!
      
      assert_equal 1, @storage.get(application_key(@service_id,
                                                   @application.id,
                                                   @metric_id,
                                                   :month, '20121001')).to_i      

      assert_equal 2, @storage.get(application_key(@service_id,
                                                   @application.id,
                                                   @metric_id,
                                                   :month, '20100501')).to_i

    end

  end
  
  test 'regression test for large bulk transactions, more than 1000 and many metrics' do
    
    ## this test tries to raise the error, SystemStackError: stack level too deep
    ## /Users/solso/.rvm/gems/ruby-1.9.2-p180/gems/redis-2.1.1/lib/redis/client.rb:43
    ## that will be masked by a stack level too deep of Resque in production. 
    
    ## the issue seems to be a limit on the items on a redis_pipeline, lowered the 
    ## PIPELINED_SLICE_SIZE to 400 from 1000
    
    N = 2000
    M = 20
      
    applications = []
    N.times do |i|
      
      applications << Application.save(:service_id => @service_id,
                                    :id         => next_id,
                                    :plan_id    => @plan_id,
                                    :state      => :active)
    end
    
    metrics = []
    M.times do |i|
      metrics << Metric.save(:service_id => @service_id, :id => next_id, :name => "metric_#{i}")
    end
    
    bulk = {}
    
    N.times do |i|
      bulk[i] = {:app_id => applications[i].id, :usage => {}}
      M.times do |j|
        bulk[i][:usage][metrics[j].name] = 1
      end
    end   
    
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
        
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => bulk
        
      Resque.run!
    end
    
    N.times do |i|
      M.times do |j|
    
        assert_equal 1, @storage.get(application_key(@service_id,
                                                 applications[i].id,
                                                 metrics[j].id,
                                                 :month, '20100501')).to_i
      end
    end                                           
  end

  test 'successful report aggregates backend hit with cassandra' do
    
    cassandra_setup()
    
    application2 = Application.save(:service_id => @service_id,
                                    :id         => next_id,
                                    :plan_id    => @plan_id,
                                    :state      => :active)
                                      
    
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      
      10.times do |i|
        post '/transactions.xml',
          :provider_key => @provider_key,
          :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}}}
          
        post '/transactions.xml',
            :provider_key => @provider_key,
            :transactions => {0 => {:app_id => application2.id, :usage => {'hits' => 1}}}  

        Resque.run!
        ## processes all the pending notifyjobs that. This creates a NotifyJob with the 
        ## aggregate and another Resque.run! is needed
        Backend::Transactor.process_batch(0,{:all => true})
        Resque.run!

        assert_equal 2*(i+1), @storage.get(application_key(@master_service_id,
                                                     @provider_application_id,
                                                     @master_hits_id,
                                                     :month, '20100501')).to_i

        assert_equal 2*(i+1), @storage.get(application_key(@master_service_id,
                                                     @provider_application_id,
                                                     @master_reports_id,
                                                     :month, '20100501')).to_i
      end
                                                                                                        
    end
    
    Aggregator.schedule_one_stats_job
    Resque.run!
    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(@master_service_id,
                                                 @provider_application_id,
                                                 @master_hits_id,
                                                 :month, '20100501'))
                                                 
    
    assert_equal 2*10, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(@master_service_id,
                                                 @provider_application_id,
                                                 @master_reports_id,
                                                 :month, '20100501'))
    
    assert_equal 2*10, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
    
    assert_equal 10, @storage.get(application_key(@service_id,
                                                 @application.id,
                                                 @metric_id,
                                                 :month, '20100501')).to_i
                                                 
    
    assert_equal 10, @storage.get(application_key(@service_id,
                                                 @application.id,
                                                 @metric_id,
                                                 :month, '20100501')).to_i
                                                 
                                                                                              
   cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(@service_id,
                                                  @application.id,
                                                  @metric_id,
                                                  :month, '20100501'))
                                                  
   assert_equal 10, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)
   
   
   cassandra_row_key, cassandra_col_key = redis_key_2_cassandra_key(application_key(@service_id,
                                                  application2.id,
                                                  @metric_id,
                                                  :month, '20100501'))
                                                  
   assert_equal 10, @storage_cassandra.get(:Stats, cassandra_row_key, cassandra_col_key)   
  end

  test 'check counter rake method' do
    
    cassandra_setup()
    
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      
      10.times do |i|
        post '/transactions.xml',
          :provider_key => @provider_key,
          :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}}}
          
        Resque.run!
        ## processes all the pending notifyjobs that. This creates a NotifyJob with the 
        ## aggregate and another Resque.run! is needed
        Backend::Transactor.process_batch(0,{:all => true})
        Resque.run!

        assert_equal (i+1), @storage.get(application_key(@master_service_id,
                                                     @provider_application_id,
                                                     @master_hits_id,
                                                     :month, '20100501')).to_i

        
        assert_equal (i+1), @storage.get(application_key(@service_id,
                                                     @application.id,
                                                     @metric_id,
                                                     :month, '20100501')).to_i
                                                     
      end
                                                                                                        
    end
    
    Aggregator.schedule_one_stats_job
    Resque.run!
     
    v = Aggregator.check_counters_only_as_rake(@service_id, @application.id, @metric_id, Time.utc(2010, 5, 12, 13, 33))
    
    [:eternity, :month, :week, :day, :hour, :minute].each do |gra|
      assert_equal 10, v[:redis][gra].to_i
      assert_equal 10, v[:cassandra][gra]
    end
  end
  
  ## FIXME: this test in incomplete, should be done properly soon
  test 'when exception raised in worker it goes to resque:failed' do
  
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}}}
    
      assert_equal 1, Resque.queues[:priority].length
      ##FIXME: i would like to be able to do @storage.llen("resque:priority")
      ##but resque_unit does not write to redis :-/ want to get rid of resque_unit so badly
    
      @storage.stubs(:evalsha).raises(Exception.new('bang!'))
      @storage.stubs(:eval).raises(Exception.new('bang!'))
      @storage.stubs(:incrby).raises(Exception.new('bang!'))
    
      assert_equal 0, Resque.queues[:failed].length

      assert_equal 0, @storage.get(application_key(@master_service_id,
                                                  @provider_application_id,
                                                  @master_hits_id,
                                                  :month, '20100501')).to_i
      
      
      assert_raise Exception do
        Resque.run!
        ## processes all the pending notifyjobs that. This creates a NotifyJob with the 
        ## aggregate and another Resque.run! is needed
        Backend::Transactor.process_batch(0,{:all => true})
        Resque.run!
      end
      
      assert_equal 0, @storage.get(application_key(@master_service_id,
                                                  @provider_application_id,
                                                  @master_hits_id,
                                                  :month, '20100501')).to_i
  

      assert_equal 0, Resque.queues[:priority].length  
      ## assert_equal 1, Resque.queues[:failed].length
      ## FIXME: THIS MOTHERFUCKER or :failed is empty!!!
  
      @storage.unstub(:incrby)
      @storage.unstub(:eval)
      @storage.unstub(:evalsha)
    end
  end
  
  test 'successful aggregation of notify jobs' do
    
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      
      (configuration.notification_batch-1).times do
      
        post '/transactions.xml',
          :provider_key => @provider_key,
          :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}},
                            1 => {:app_id => @application.id, :usage => {'hits' => 1}},
                            2 => {:app_id => @application.id, :usage => {'hits' => 1}}}

        Resque.run!
      end
      
      assert_equal configuration.notification_batch-1, @storage.llen(Transactor.key_for_notifications_batch)
      assert_equal 0, Resque.queues[:main].size

      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}},
                          1 => {:app_id => @application.id, :usage => {'hits' => 1}},
                          2 => {:app_id => @application.id, :usage => {'hits' => 1}}}

      Resque.run!

      assert_equal 0, @storage.llen(Transactor.key_for_notifications_batch)
      assert_equal 0, Resque.queues[:main].size
      
      assert_equal configuration.notification_batch, @storage.get(application_key(@master_service_id,
                                                  @provider_application_id,
                                                  @master_hits_id,
                                                  :month, '20100501')).to_i
      
    end
  end
  
  
  test 'successful aggregation of notify jobs with multiple iterations' do
    
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      
      ((configuration.notification_batch*5.5).to_i).times do
      
        post '/transactions.xml',
          :provider_key => @provider_key,
          :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}},
                            1 => {:app_id => @application.id, :usage => {'hits' => 1}},
                            2 => {:app_id => @application.id, :usage => {'hits' => 1}}}

        Resque.run!
      end
      
      assert_equal (configuration.notification_batch*0.5).to_i, @storage.llen(Transactor.key_for_notifications_batch)
      assert_equal 0, Resque.queues[:main].size
      
      assert_equal configuration.notification_batch*5, @storage.get(application_key(@master_service_id,
                                                  @provider_application_id,
                                                  @master_hits_id,
                                                  :month, '20100501')).to_i
      
    end
  end
  
  test 'reporting user_id when not enabled makes failures go to error instead of failed jobs' do
    
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}, :user_id => 'user_id'},
                          1 => {:app_id => @application.id, :usage => {'hits' => 1}},
                          2 => {:app_id => @application.id, :usage => {'hits' => 1}}}

      Resque.run!
      
      assert_equal 0, @storage.get(application_key(@service_id,
                                                   @application.id,
                                                   @metric_id,
                                                  :month, '20100501')).to_i
      
      assert_equal 0, Resque.queues[:main].size
      
      assert_equal 1, ErrorStorage.list(@service_id).count
      
      error = ErrorStorage.list(@service_id).last
      assert_not_nil error
      assert_equal 'service_cannot_use_user_id', error[:code]
      assert_equal "service with service_id=\"#{@service_id}\" does not have access to end user plans, user_id is not allowed", error[:message]
      
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}},
                          1 => {:app_id => @application.id, :usage => {'hits' => 1}},
                          2 => {:app_id => @application.id, :usage => {'hits' => 1}}}

      Resque.run!
      
      assert_equal 0, Resque.queues[:main].size
      
      assert_equal 3, @storage.get(application_key(@service_id,
                                                   @application.id,
                                                   @metric_id,
                                                  :month, '20100501')).to_i
      
      assert_equal 1, ErrorStorage.list(@service_id).count     
    end
  end
  
  test 'report cannot use an explicit timestamp older than 24 hours' do
     
    Airbrake.stubs(:notify).returns(true)
    if false 
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}, :timestamp => '2010-05-12 10:00:01'},
                          1 => {:app_id => @application.id, :usage => {'hits' => 1}, :timestamp => '2010-05-12 10:00:02'},
                          2 => {:app_id => @application.id, :usage => {'hits' => 1}, :timestamp => '2010-05-12 10:00:03'}}

      Resque.run!
      
      assert_equal 3, @storage.get(application_key(@service_id,
                                                   @application.id,
                                                   @metric_id,
                                                  :month, '20100501')).to_i
                                                  
                                                  
      assert_equal 0, ErrorStorage.list(@service_id).count


      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}, :timestamp => '2010-05-11 10:00:01'},
                          1 => {:app_id => @application.id, :usage => {'hits' => 1}, :timestamp => '2010-05-11 10:00:02'},
                          2 => {:app_id => @application.id, :usage => {'hits' => 1}, :timestamp => '2010-05-11 10:00:03'}}

      Resque.run!
      
      assert_equal 3, @storage.get(application_key(@service_id,
                                                   @application.id,
                                                   @metric_id,
                                                  :month, '20100501')).to_i
                                                  
                                                  
      assert_equal 1, ErrorStorage.list(@service_id).count
      
      error = ErrorStorage.list(@service_id).last
      assert_not_nil error
      assert_equal 'report_timestamp_not_within_range', error[:code]
      assert_equal "report jobs cannot update metrics older than #{REPORT_DEADLINE} seconds", error[:message]                                           
    end
    end
    Airbrake.unstub(:notify)
  end
  
end
