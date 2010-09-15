require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class TransactorTest < Test::Unit::TestCase
  include TestHelpers::MasterService

  def setup
    # TODO: all this fixtures are maybe not necessary here. Revise!
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!

    setup_master_service

    @provider_key = 'provider_key'
    Application.save(:id         => @provider_key,
                     :service_id => @master_service_id,
                     :state      => :active)

    @service_id = next_id
    Core::Service.save(:provider_key => @provider_key, :id => @service_id)

    @metric_id = next_id
    Metric.save(:service_id => @service_id, :id => @metric_id, :name => 'hits')

    @plan_id = next_id
    @plan_name = 'killer'
    
    @application_id_one = next_id
    Application.save(:service_id => @service_id,
                     :id => @application_id_one,
                     :state => :active,
                     :plan_id => @plan_id,
                     :plan_name => @plan_name)
    
    @application_id_two = next_id
    Application.save(:service_id => @service_id,
                     :id => @application_id_two,
                     :state => :active,
                     :plan_id => @plan_id,
                     :plan_name => @plan_name)
  end

  test 'report queues transactions to report' do
    Transactor.report(@provider_key, '0' => {'app_id' => @application_id_one,
                                             'usage'  => {'hits' => 1}},
                                     '1' => {'app_id' => @application_id_two,
                                             'usage'  => {'hits' => 1}})

    assert_queued Transactor::ReportJob,
                  [@service_id,
                    {'0' => {'app_id' => @application_id_one, 'usage' => {'hits' => 1}},
                     '1' => {'app_id' => @application_id_two, 'usage' => {'hits' => 1}}}]
  end
  
  test 'report raises an exception when provider key is invalid' do
    assert_raise ProviderKeyInvalid do
      Transactor.report('booo', '0' => {'app_id' => @application_id_one,
                                        'usage'  => {'hits' => 1}})
    end
  end
  
  test 'report queues backend hit' do
    Timecop.freeze(Time.utc(2010, 7, 29, 11, 48)) do
      Transactor.report(@provider_key, '0' => {'app_id' => @application_id_one,
                                               'usage'  => {'hits' => 1}},
                                       '1' => {'app_id' => @application_id_two,
                                               'usage'  => {'hits' => 1}})

      assert_queued Transactor::NotifyJob, 
                    [@provider_key, 
                     {'transactions/create_multiple' => 1,
                      'transactions'                 => 2},
                     '2010-07-29 11:48:00 UTC']
    end
  end

  test 'authorize returns status object with the plan name' do
    status = Transactor.authorize(@provider_key, :app_id => @application_id_one)

    assert_not_nil status
    assert_equal @plan_name, status.plan_name
  end

  test 'authorize returns status object with usage reports if the plan has usage limits' do
    UsageLimit.save(:service_id => @service_id, 
                    :plan_id    => @plan_id, 
                    :metric_id  => @metric_id,
                    :month      => 10000, 
                    :day        => 200)

    Timecop.freeze(Time.utc(2010, 5, 13)) do
      Transactor.report(@provider_key,
                        0 => {'app_id' => @application_id_one, 
                              'usage'  => {'hits' => 3}})
      Resque.run!
    end

    Timecop.freeze(Time.utc(2010, 5, 14)) do
      Transactor.report(@provider_key,
                        0 => {'app_id' => @application_id_one, 
                              'usage'  => {'hits' => 2}})
      Resque.run!
    end


    Timecop.freeze(Time.utc(2010, 5, 14)) do
      status = Transactor.authorize(@provider_key, :app_id => @application_id_one)
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
    end
  end
  
  test 'authorize returns status object without usage reports if the plan has no usage limits' do
    status = Transactor.authorize(@provider_key, :app_id => @application_id_one)
    assert_equal 0, status.usage_reports.count
  end

  test 'authorize returns unauthorized status object when application is suspended' do
    application = Application.load(@service_id, @application_id_one)
    application.state = :suspended
    application.save

    status = Transactor.authorize(@provider_key, :app_id => @application_id_one)
    assert !status.authorized?
    assert_equal 'application_not_active',    status.rejection_reason_code
    assert_equal 'application is not active', status.rejection_reason_text
  end
  
  test 'authorize returns unauthorized status object when usage limits are exceeded' do
    UsageLimit.save(:service_id => @service_id, 
                    :plan_id    => @plan_id, 
                    :metric_id  => @metric_id,
                    :day        => 4)

    Timecop.freeze(Time.utc(2010, 5, 14)) do
      Transactor.report(@provider_key, 0 => {'app_id' => @application_id_one,
                                             'usage' => {'hits' => 5}})
      Resque.run!
    end

    Timecop.freeze(Time.utc(2010, 5, 14)) do
      status = Transactor.authorize(@provider_key, :app_id => @application_id_one)
      assert !status.authorized?
      assert_equal 'limits_exceeded',           status.rejection_reason_code
      assert_equal 'usage limits are exceeded', status.rejection_reason_text
    end
  end
  
  test 'authorize succeeds if there are usage limits that are not exceeded' do
    UsageLimit.save(:service_id => @service_id, 
                    :plan_id    => @plan_id, 
                    :metric_id  => @metric_id,
                    :day        => 4)

    Timecop.freeze(Time.utc(2010, 5, 14)) do
      Transactor.report(@provider_key, 0 => {'app_id' => @application_id_one,
                                             'usage'  => {'hits' => 3}})

      status = Transactor.authorize(@provider_key, :app_id => @application_id_one)
      assert status.authorized?
    end
  end

  test 'authorize succeeds if no application key is defined nor passed' do
    status = Transactor.authorize(@provider_key, :app_id => @application_id_one)
    assert status.authorized?
  end
  
  def test_authorize_succeeds_if_no_application_key_is_defined_and_blank_one_is_passed
    status = Transactor.authorize(@provider_key, :app_id  => @application_id_one,
                                                 :app_key => '')
    assert status.authorized?
  end

  test 'authorize succeeds if one application key is defined and the same is passed' do
    application = Application.load(@service_id, @application_id_one)
    application_key = application.create_key

    status = Transactor.authorize(@provider_key, :app_id  => @application_id_one,
                                                 :app_key => application_key)
    assert status.authorized?
  end
  
  test 'authorize succeeds if multiple application keys are defined and one of them is passed' do
    application = Application.load(@service_id, @application_id_one)
    application_key_one = application.create_key
    application_key_two = application.create_key

    status = Transactor.authorize(@provider_key, :app_id  => @application_id_one,
                                                 :app_key => application_key_one)
    assert status.authorized?
  end

  test 'authorize returns unauthorized status object if application key is defined but not passed' do
    application = Application.load(@service_id, @application_id_one)
    application.create_key
    
    status = Transactor.authorize(@provider_key, :app_id => @application_id_one)

    assert !status.authorized?
    assert_equal 'application_key_invalid',    status.rejection_reason_code
    assert_equal 'application key is missing', status.rejection_reason_text
  end
  
  test 'authorize returns unauthorized status object if invalid application key is passed' do
    application = Application.load(@service_id, @application_id_one)
    application.create_key('foo')
    
    status = Transactor.authorize(@provider_key, :app_id  => @application_id_one,
                                                 :app_key => 'bar')

    assert !status.authorized?
    assert_equal 'application_key_invalid',          status.rejection_reason_code
    assert_equal 'application key "bar" is invalid', status.rejection_reason_text
  end
  
  def test_authorize_raises_an_exception_when_provider_key_is_invalid
    assert_raise ProviderKeyInvalid do
      Transactor.authorize('booo', @application_id_one)
    end
  end
  
  test 'authorize raises an exception when application id is invalid' do
    assert_raise ApplicationNotFound do
      Transactor.authorize(@provider_key, :app_id => 'baaa')
    end
  end
  
  test 'authorize queues backend hit' do
    Timecop.freeze(Time.utc(2010, 7, 29, 17, 9)) do
      Transactor.authorize(@provider_key, :app_id => @application_id_one)

      assert_queued Transactor::NotifyJob, 
                    [@provider_key, 
                     {'transactions/authorize' => 1},
                     '2010-07-29 17:09:00 UTC']
    end
  end
end
