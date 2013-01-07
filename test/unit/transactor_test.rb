require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class TransactorTest < Test::Unit::TestCase
  include TestHelpers::Fixtures

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!

    setup_provider_fixtures

    @application_one = Application.save(:service_id => @service_id,
                                        :id         => next_id,
                                        :state      => :active,
                                        :plan_id    => @plan_id,
                                        :plan_name  => @plan_name)

    @application_two = Application.save(:service_id => @service_id,
                                        :id         => next_id,
                                        :state      => :active,
                                        :plan_id    => @plan_id,
                                        :plan_name  => @plan_name)

    @metric_id = next_id
    Metric.save(:service_id => @service_id, :id => @metric_id, :name => 'hits')
  end

  test 'report queues transactions to report' do
    Timecop.freeze(Time.utc(2011, 12, 12, 11, 48)) do
      Transactor.report(@provider_key, nil, '0' => {'app_id' => @application_one.id,
                                                'usage'  => {'hits' => 1}},
                                              '1' => {'app_id' => @application_two.id,
                                                'usage'  => {'hits' => 1}})

      assert_queued Transactor::ReportJob,
                    [@service_id,
                      {'0' => {'app_id' => @application_one.id, 'usage' => {'hits' => 1}},
                      '1' => {'app_id' => @application_two.id, 'usage' => {'hits' => 1}}},
                      Time.utc(2011, 12, 12, 11, 48).to_f]
      end
                    
  end

  test 'report queues transactions to report with explicit service id' do
    Timecop.freeze(Time.utc(2011, 12, 12, 11, 48)) do
      Transactor.report(@provider_key, @service_id, '0' => {'app_id' => @application_one.id,
                                                'usage'  => {'hits' => 1}},
                                              '1' => {'app_id' => @application_two.id,
                                                'usage'  => {'hits' => 1}})

      assert_queued Transactor::ReportJob,
                    [@service_id,
                      {'0' => {'app_id' => @application_one.id, 'usage' => {'hits' => 1}},
                      '1' => {'app_id' => @application_two.id, 'usage' => {'hits' => 1}}},
                      Time.utc(2011, 12, 12, 11, 48).to_f]
    end                  
  end



  test 'report raises an exception when provider key is invalid' do
    assert_raise ProviderKeyInvalid do
      Transactor.report('booo', nil, '0' => {'app_id' => @application_one.id,
                                        'usage'  => {'hits' => 1}})
    end
  end

  test 'report raises an exception when provider key is invalid even with a valid service id' do
    assert_raise ProviderKeyInvalid do
      Transactor.report('booo', @service_id, '0' => {'app_id' => @application_one.id,
                                        'usage'  => {'hits' => 1}})
    end
  end


  test 'report queues backend hit' do
    Timecop.freeze(Time.utc(2010, 7, 29, 11, 48)) do
      Transactor.report(@provider_key, nil, '0' => {'app_id' => @application_one.id,
                                               'usage'  => {'hits' => 1}},
                                       '1' => {'app_id' => @application_two.id,
                                               'usage'  => {'hits' => 1}})
                                               
      ## processes all the pending notifyjobs.
      Transactor.process_batch(0,{:all => true})
      
      assert_queued Transactor::NotifyJob,
                    [@provider_key,
                     {'transactions/create_multiple' => 1,
                      'transactions'                 => 2},
                     '2010-07-29 11:48:00 UTC',
                     Time.utc(2010, 7, 29, 11, 48).to_f]
    end
  end

 test 'report queues backend hit with explicit service id' do
    Timecop.freeze(Time.utc(2010, 7, 29, 11, 48)) do
      Transactor.report(@provider_key, @service_id, '0' => {'app_id' => @application_one.id,
                                               'usage'  => {'hits' => 1}},
                                       '1' => {'app_id' => @application_two.id,
                                               'usage'  => {'hits' => 1}})

      ## processes all the pending notifyjobs.
      Transactor.process_batch(0,{:all => true})
                                               
      assert_queued Transactor::NotifyJob,
                    [@provider_key,
                     {'transactions/create_multiple' => 1,
                      'transactions'                 => 2},
                     '2010-07-29 11:48:00 UTC',
                     Time.utc(2010, 7, 29, 11, 48).to_f]
    end
  end


  test 'authorize returns status object with the plan name' do
    status = Transactor.authorize(@provider_key, :app_id => @application_one.id)

    assert_not_nil status.first
    assert_equal @plan_name, status.first.plan_name
  end



  test 'authorize returns status object with usage reports if the plan has usage limits' do
    UsageLimit.save(:service_id => @service_id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :month      => 10000,
                    :day        => 200)

    Timecop.freeze(Time.utc(2010, 5, 13)) do
      Transactor.report(@provider_key, nil,
                        0 => {'app_id' => @application_one.id,
                              'usage'  => {'hits' => 3}})
      Resque.run!
      ## processes all the pending notifyjobs that. This creates a NotifyJob with the 
      ## aggregate and another Resque.run! is needed
      Transactor.process_batch(0,{:all => true})
      Resque.run!
    end

    Timecop.freeze(Time.utc(2010, 5, 14)) do
      Transactor.report(@provider_key, @service_id,
                        0 => {'app_id' => @application_one.id,
                              'usage'  => {'hits' => 2}})
      Resque.run!
      ## processes all the pending notifyjobs that. This creates a NotifyJob with the 
      ## aggregate and another Resque.run! is needed
      Transactor.process_batch(0,{:all => true})
      Resque.run!
    end


    Timecop.freeze(Time.utc(2010, 5, 14)) do
      status, status_xml, status_result = Transactor.authorize(@provider_key, :app_id => @application_one.id)
      
      if not status.nil?
        assert_equal 2, status.usage_reports.count

        report_month = status.usage_reports.find { |report| report.period == :month }
        assert_not_nil       report_month
        assert_equal 'hits', report_month.metric_name
        assert_equal 5,      report_month.current_value
        assert_equal 10000,  report_month.max_value

        report_day = status.usage_reports.find { |report| report.period == :day }
        assert_not_nil       report_day
        assert_equal 'hits', report_day.metric_name
        assert_equal 2,      report_day.current_value
        assert_equal 200,    report_day.max_value
      else

        ## this means it comes from the cache, 
        ## warning: need to reproduce the above asserts for xml
        assert_not_nil status_xml
        assert_not_nil status_result

        status, tmp1, tmp2 = Transactor.authorize(@provider_key, { :service_id => @service_id, :app_id => @application_one.id, :no_caching => true })

        assert_not_nil status
        assert_equal  tmp1, nil
        assert_equal  tmp2, nil

        assert_equal status_xml, status.to_xml                

      end
    end
  end

  test 'report raises an exception when invalid provider_key and service_id' do
    assert_raise ProviderKeyInvalid do
      Transactor.report(@provider_key, "fake_service_id",
                        0 => {'app_id' => @application_one.id,
                              'usage'  => {'hits' => 3}})
    end

    assert_raise ProviderKeyInvalid do
      Transactor.report("fake_provider_key", @service_id,
                        0 => {'app_id' => @application_one.id,
                              'usage'  => {'hits' => 3}})
    end



  end



  test 'authorize returns status object without usage reports if the plan has no usage limits' do
    status, status_xml, status_result = Transactor.authorize(@provider_key, :app_id => @application_one.id)
    if not status.nil?
      assert_equal 0, status.usage_reports.count
    else
      assert_not_nil status_xml
      assert_not_nil status_result

      status, tmp1, tmp2 = Transactor.authorize(@provider_key, { :app_id => @application_one.id, :no_caching => true })

      assert_not_nil status
      assert_equal  tmp1, nil
      assert_equal  tmp2, nil

      assert_equal status_xml, status.to_xml   

      ## warning: need to reproduce the above asserts for xml
    end
  end

  test 'authorize raises an exception when provider key is invalid' do
    assert_raise ProviderKeyInvalid do
      Transactor.authorize('booo', :app_id => @application_one.id)
    end
  end

  test 'authorize raises an exception when application id is invalid' do
    assert_raise ApplicationNotFound do
      Transactor.authorize(@provider_key, :app_id => 'baaa')
    end
  end

  test 'authorize raises an exception when application id is missing' do
    assert_raise ApplicationNotFound do
      Transactor.authorize(@provider_key, {})
    end
  end

  test 'authorize works with legacy user key' do
    user_key = 'foobar'
    Application.save_id_by_key(@service_id, user_key, @application_one.id)

    assert_not_nil Transactor.authorize(@provider_key, :user_key => user_key)
  end

  test 'authorize raises an exception when legacy user key is invalid' do
    Application.save_id_by_key(@service_id, 'foobar', @application_one.id)

    assert_raise UserKeyInvalid do
      Transactor.authorize(@provider_key, :user_key => 'eatthis')
    end
  end

  test 'authorize raises an exception when both application id and legacy user key are passed' do
    user_key = 'foobar'
    Application.save_id_by_key(@service_id, user_key, @application_one.id)

    assert_raise AuthenticationError do
      Transactor.authorize(@provider_key, :app_id   => @application_one.id,
                                          :user_key => user_key)
    end
  end

  test 'authorize queues backend hit' do
    Timecop.freeze(Time.utc(2010, 7, 29, 17, 9)) do
      Transactor.authorize(@provider_key, :app_id => @application_one.id)

      ## processes all the pending notifyjobs.
      Transactor.process_batch(0,{:all => true})

      assert_queued Transactor::NotifyJob,
                    [@provider_key,
                     {'transactions/authorize' => 1},
                     '2010-07-29 17:09:00 UTC',
                     Time.utc(2010, 7, 29, 17, 9).to_f]
    end
  end

  test 'authrep returns status object without usage reports if the plan has no usage limits' do
    status, status_xml, status_result = Transactor.authrep(@provider_key, :app_id => @application_one.id)
    if not status.nil?
      assert_equal 0, status.usage_reports.count
    else
      assert_not_nil status_xml
      assert_not_nil status_result

      status, tmp1, tmp2 = Transactor.authrep(@provider_key, { :app_id => @application_one.id, :no_caching => true })

      assert_not_nil status
      assert_equal  tmp1, nil
      assert_equal  tmp2, nil

      assert_equal status_xml, status.to_xml   

      ## warning: need to reproduce the above asserts for xml
    end
  end

  test 'authrep raises an exception when provider key is invalid' do
    assert_raise ProviderKeyInvalid do
      Transactor.authrep('booo', :app_id => @application_one.id)
    end
  end

  test 'authrep raises an exception when application id is invalid' do
    assert_raise ApplicationNotFound do
      Transactor.authrep(@provider_key, :app_id => 'baaa')
    end
  end

  test 'authrep raises an exception when application id is missing' do
    assert_raise ApplicationNotFound do
      Transactor.authrep(@provider_key, {})
    end
  end

  test 'authrep works with legacy user key' do
    user_key = 'foobar'
    Application.save_id_by_key(@service_id, user_key, @application_one.id)

    assert_not_nil Transactor.authrep(@provider_key, :user_key => user_key)
  end

  test 'authrep raises an exception when legacy user key is invalid' do
    Application.save_id_by_key(@service_id, 'foobar', @application_one.id)

    assert_raise UserKeyInvalid do
      Transactor.authrep(@provider_key, :user_key => 'eatthis')
    end
  end

  test 'authrep raises an exception when both application id and legacy user key are passed' do
    user_key = 'foobar'
    Application.save_id_by_key(@service_id, user_key, @application_one.id)

    assert_raise AuthenticationError do
      Transactor.authrep(@provider_key, :app_id   => @application_one.id,
                                          :user_key => user_key)
    end
  end

  test 'authrep queues backend hit' do
    Timecop.freeze(Time.utc(2010, 7, 29, 17, 9)) do
      Transactor.authrep(@provider_key, :app_id => @application_one.id)

      ## processes all the pending notifyjobs.
      Transactor.process_batch(0,{:all => true})
      
      assert_queued Transactor::NotifyJob,
                    [@provider_key,
                     {'transactions/authorize' => 1},
                     '2010-07-29 17:09:00 UTC',
                     Time.utc(2010, 7, 29, 17, 9).to_f]
    end
  end


end
