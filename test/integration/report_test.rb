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

    @apilog = {'request' => 'API original request', 'response' => 'API original response', 'code' => '200'}
    @apilog2 = {'request' => 'API original request 2', 'response' => 'API original response 2', 'code' => '200'}
    @apilog3 = {'request' => 'API original request 3', 'response' => 'API original response 3', 'code' => '200'}
    @apilog_imcomplete = {'code' => '200'}
    @apilog_empty = {}

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

  test 'successful report with utc timestamped transactions' do
    Timecop.freeze(Time.utc(2010, 4, 23, 00, 00)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id    => @application.id,
                                :usage     => {'hits' => 1},
                                :timestamp => '2010-04-22 23:59:30'}}
      Resque.run!

      key = service_key(@service_id, @metric_id, :hour, '2010042223')
      assert_equal 1, @storage.get(key).to_i
    end
  end

  test 'successful report with UTC timestamped transactions' do
    Timecop.freeze(Time.utc(2010, 4, 23, 00, 00)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id    => @application.id,
                                :usage     => {'hits' => 1},
                                :timestamp => '2010-04-22 23:59:25 UTC'}}
      Resque.run!

      key = service_key(@service_id, @metric_id, :hour, '2010042223')
      assert_equal 1, @storage.get(key).to_i
    end
  end

  test 'successful report with proper local timestamped transactions' do
    Timecop.freeze(Time.utc(2010, 4, 23, 00, 00)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id    => @application.id,
                                :usage     => {'hits' => 1},
                                :timestamp => '2010-04-22 23:55:45 +0200'}}
      Resque.run!

      key = service_key(@service_id, @metric_id, :hour, '2010042221')
      assert_equal 1, @storage.get(key).to_i
    end
  end

  test 'successful report with local timestamped transactions' do
    Timecop.freeze(Time.utc(2010, 4, 23, 00, 00)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id    => @application.id,
                                :usage     => {'hits' => 1},
                                :timestamp => '2010-04-22 21:00:25 -02:00'}}
      Resque.run!

      key = service_key(@service_id, @metric_id, :hour, '2010042223')
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
    provider_key = 'invalid_key'

    post '/transactions.xml',
      :provider_key => provider_key,
      :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}, :log => @apilog}}

    assert_error_resp_with_exc(ProviderKeyInvalidOrServiceMissing.new(provider_key))
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

      ## processes all the pending NotifyJobs. This creates a NotifyJob with the
      ## aggregate and another Resque.run! is needed
      Backend::Transactor.process_batch(0, all: true)
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

      Backend::Transactor.process_batch(0, all: true)
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

      Backend::Transactor.process_batch(0, all: true)
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

      Backend::Transactor.process_batch(0, all: true)
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

      Backend::Transactor.process_batch(0, all: true)
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
        :provider_key => 'fake_provider_key',
        :transactions => {0 => {:app_id => 'baa',           :usage => {'hits' => 1}},
                          1 => {:app_id => @application.id, :usage => {'hits' => 1}}}
      Resque.run!

      Backend::Transactor.process_batch(0, all: true)
      Resque.run!

      assert_equal 403, last_response.status

      doc = Nokogiri::XML(last_response.body)
      error = doc.at('error:root')
      assert_not_nil error
      assert_equal 'provider_key_invalid_or_service_missing', error['code']

      assert_equal 0, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_transactions_id,
                                                   :month, '20100501')).to_i

      post '/transactions.xml',
        :provider_key => @provider_key,
        :service_id => 'fake_service_id',
        :transactions => {0 => {:app_id => 'baa',           :usage => {'hits' => 1}},
                          1 => {:app_id => @application.id, :usage => {'hits' => 1}}}
      Resque.run!

      Backend::Transactor.process_batch(0, all: true)
      Resque.run!

      assert_equal 403, last_response.status

      doc = Nokogiri::XML(last_response.body)
      error = doc.at('error:root')
      assert_not_nil error
      assert_equal 'service_id_invalid', error['code']

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

      Backend::Transactor.process_batch(0, all: true)
      Resque.run!

      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_transactions_id,
                                                   :month, '20100501')).to_i

      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}, :timestamp => ''}}
      Resque.run!

      Backend::Transactor.process_batch(0, all: true)
      Resque.run!

      assert_equal 2, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_transactions_id,
                                                   :month, '20100501')).to_i

      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}, :timestamp => '0'}}
      Resque.run!

      Backend::Transactor.process_batch(0, all: true)
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

    end

    Timecop.freeze(Time.utc(2012, 10, 01)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}, :timestamp => '2012/10/01'}}
      Resque.run!

      assert_equal 1, @storage.get(application_key(@service_id,
                                                   @application.id,
                                                   @metric_id,
                                                   :month, '20121001')).to_i
    end

    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}, :timestamp => '2012'}}
      Resque.run!

      # This part is tricky. '2012' is an invalid timestamp, so it gets set to
      # the current timestamp. As a result, month 20121001 is not incremented,
      # but month 20100501 is.

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

  ## FIXME: this test in incomplete, should be done properly soon
  test 'when exception raised in worker it goes to resque:failed' do
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}}}

      assert_equal 1, Resque.queues[:priority].length
      ##FIXME: i would like to be able to do @storage.llen('resque:priority')
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

        Backend::Transactor.process_batch(0, all: true)
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

  test 'reporting a transaction with a past timestamp within the limits does not generate errors' do
    past_limit = Transaction.const_get(:REPORT_DEADLINE_PAST)
    current_time = Time.utc(2016, 2, 10)
    current_month = current_time.strftime('%Y%m01')
    transaction_time = current_time - past_limit
    transactions =
        { 0 => { app_id: @application.id,
                 usage: { 'hits' => 1 },
                 timestamp: transaction_time },
          1 => { app_id: @application.id,
                 usage: { 'hits' => 2 },
                 timestamp: transaction_time } }

    Timecop.freeze(current_time) do
      post '/transactions.xml', provider_key: @provider_key, transactions: transactions

      Resque.run!

      assert_equal 3, @storage.get(
          application_key(@service_id, @application.id, @metric_id, :month, current_month)).to_i
      assert_equal 0, ErrorStorage.count(@service_id)
    end
  end

  test 'reporting a transaction with a future timestamp within the limits does not generate errors' do
    future_limit = Transaction.const_get(:REPORT_DEADLINE_FUTURE)
    current_time = Time.utc(2016, 2, 10)
    current_month = current_time.strftime('%Y%m01')
    transaction_time = current_time + future_limit
    transactions =
        { 0 => { app_id: @application.id,
                 usage: { 'hits' => 1 },
                 timestamp: transaction_time },
          1 => { app_id: @application.id,
                 usage: { 'hits' => 2 },
                 timestamp: transaction_time } }

    Timecop.freeze(current_time) do
      post '/transactions.xml', provider_key: @provider_key, transactions: transactions

      Resque.run!

      assert_equal 3, @storage.get(
          application_key(@service_id, @application.id, @metric_id, :month, current_month)).to_i
      assert_equal 0, ErrorStorage.count(@service_id)
    end
  end

  test 'reporting transactions with a timestamp too old' do
    past_limit = Transaction.const_get(:REPORT_DEADLINE_PAST)
    current_time = Time.utc(2016, 2, 1)
    current_month = current_time.strftime('%Y%m01')
    transaction_time = current_time - past_limit - 1
    transactions =
        { 0 => { app_id: @application.id,
                 usage: { 'hits' => 1 },
                 timestamp: transaction_time },
          1 => { app_id: @application.id,
                 usage: { 'hits' => 2 },
                 timestamp: transaction_time } }

    Timecop.freeze(current_time) do
      post '/transactions.xml', provider_key: @provider_key, transactions: transactions

      Resque.run!

      assert_equal 0, @storage.get(
          application_key(@service_id, @application.id, @metric_id, :month, current_month)).to_i

      assert_equal 1, ErrorStorage.count(@service_id)
      error = ErrorStorage.list(@service_id).last
      assert_equal TransactionTimestampTooOld.code, error[:code]
      assert_equal TransactionTimestampTooOld.new(past_limit).message, error[:message]
    end
  end

  test 'reporting transactions with a timestamp too far in the future' do
    future_limit = Transaction.const_get(:REPORT_DEADLINE_FUTURE)
    current_time = Time.utc(2016, 2, 1)
    current_month = current_time.strftime('%Y%m01')
    transaction_time = current_time + future_limit + 1
    transactions =
        { 0 => { app_id: @application.id,
                 usage: { 'hits' => 1 },
                 timestamp: transaction_time },
          1 => { app_id: @application.id,
                 usage: { 'hits' => 2 },
                 timestamp: transaction_time } }

    Timecop.freeze(current_time) do
      post '/transactions.xml', provider_key: @provider_key, transactions: transactions

      Resque.run!

      assert_equal 0, @storage.get(
          application_key(@service_id, @application.id, @metric_id, :month, current_month)).to_i

      assert_equal 1, ErrorStorage.count(@service_id)
      error = ErrorStorage.list(@service_id).last
      assert_equal TransactionTimestampTooNew.code, error[:code]
      assert_equal TransactionTimestampTooNew.new(future_limit).message, error[:message]
    end
  end

  test 'returns error if any of the reported transactions are nil' do
    post '/transactions.xml',
         :provider_key => @provider_key,
         :transactions => { 0 => { app_id: @application.id,
                                   usage: { 'hits' => 1 },
                                   timestamp: Time.now.utc },
                            1 => nil }

    assert_equal 400, last_response.status
    assert_equal '', last_response.body
  end

  test 'returns 403 if provider key is missing' do
    post '/transactions.xml',
         :transactions => { '0' => { :app_id => @application.id,
                                     :usage => { 'hits' => 1 } } }

    assert_error_resp_with_exc(ThreeScale::Backend::ProviderKeyOrServiceTokenRequired.new)
  end

  test 'returns 403 when no provider key is given, even if other params have an invalid encoding' do
    post '/transactions.xml', :transactions => "\xf0\x90\x28\xbc"

    assert_error_resp_with_exc(ThreeScale::Backend::ProviderKeyOrServiceTokenRequired.new)
  end

  test 'returns 400 when transactions is not a hash' do
    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => "\xf0\x90\x28\xbc"

    assert_equal 400, last_response.status
    assert_equal '', last_response.body

    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => 'i_am_a_string_with_valid_encoding'

    assert_equal 400, last_response.status
    assert_equal '', last_response.body
  end

  test 'returns 400 and not valid data msg when params have an invalid encoding' do
    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {"\xf0\x90\x28\xbc" => {:app_id => @application.id}}

    assert_equal 400, last_response.status
    assert_equal ThreeScale::Backend::NotValidData.new.to_xml, last_response.body

    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {'0' => {:app_id => @application.id, :usage => {"\xf0\x90\x28\xbc" => 1}}}

    assert_equal 400, last_response.status
    assert_equal ThreeScale::Backend::NotValidData.new.to_xml, last_response.body

    post '/transactions.xml',
      :provider_key => @provider_key,
      :service_id => "\xf0\x90\x28\xbc",
      :transactions => {'0' => {:app_id => @application.id, :usage => {'hits' => 1}}}

    assert_equal 400, last_response.status
    assert_equal ThreeScale::Backend::NotValidData.new.to_xml, last_response.body

    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id => "\xf0\x90\x28\xbc"}}

    assert_equal 400, last_response.status
    assert_equal ThreeScale::Backend::NotValidData.new.to_xml, last_response.body

    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {'0' => {:app_id => @application.id, :usage => {'hits' => "\xf0\x90\x28\xbc"}}}

    assert_equal 400, last_response.status
    assert_equal ThreeScale::Backend::NotValidData.new.to_xml, last_response.body
  end

  test 'report using registered (service_token, service_id) instead of provider key responds 202' do
    service_token = 'a_token'
    service_id = @service_id

    ServiceToken.save(service_token, service_id)

    post '/transactions.xml',
         :service_token => service_token,
         :service_id => service_id,
         :transactions => { 0 => { :app_id => @application.id, :usage => { 'hits' => 1 } } }

    assert_equal 202, last_response.status
  end

  test 'report using valid service token and blank service ID fails' do
    service_token = 'a_token'
    blank_service_ids = ['', nil]

    blank_service_ids.each do |blank_service_id|
      post '/transactions.xml',
           :service_token => service_token,
           :service_id => blank_service_id,
           :transactions => { 0 => { :app_id => @application.id, :usage => { 'hits' => 1 } } }

      assert_error_resp_with_exc(ThreeScale::Backend::ServiceIdMissing.new)
    end
  end

  test 'report using blank service token and valid service ID fails' do
    service_id = @service_id
    blank_service_tokens = ['', nil]

    blank_service_tokens.each do |blank_service_token|
      post '/transactions.xml',
           :service_token => blank_service_token,
           :service_id => service_id,
           :transactions => { 0 => { :app_id => @application.id, :usage => { 'hits' => 1 } } }

      assert_error_resp_with_exc(ThreeScale::Backend::ProviderKeyOrServiceTokenRequired.new)
    end
  end

  test 'report using registered token but with non-existing service ID fails' do
    service_token = 'a_token'
    service_id = 'id_non_existing_service'

    ServiceToken.save(service_token, service_id)

    post '/transactions.xml',
         :service_token => service_token,
         :service_id => service_id,
         :transactions => { 0 => { :app_id => @application.id, :usage => { 'hits' => 1 } } }

    assert_error_resp_with_exc(ThreeScale::Backend::ServiceTokenInvalid.new(service_token))
  end

  # For the next two tests, it is important to bear in mind that when both
  # provider key and service token are found in the parameters of the request,
  # the former has preference.
  test 'report using valid provider key and blank service token responds with 202' do
    provider_key = @provider_key
    service_token = nil

    post '/transactions.xml',
         :provider_key => provider_key,
         :service_token => service_token,
         :transactions => { 0 => { :app_id => @application.id, :usage => { 'hits' => 1 } } }

    assert_equal 202, last_response.status
  end

  test 'report with non-existing provider key and saved (service token, service id) fails' do
    provider_key = 'non_existing_key'
    service_token = 'a_token'
    service_id = @service_id

    ServiceToken.save(service_token, service_id)

    post '/transactions.xml',
         :provider_key => provider_key,
         :service_token => service_token,
         :service_id => service_id,
         :transactions => { 0 => { :app_id => @application.id, :usage => { 'hits' => 1 } } }

    assert_error_resp_with_exc(ThreeScale::Backend::ProviderKeyInvalid.new(provider_key))
  end
end
