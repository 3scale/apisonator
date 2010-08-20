require File.dirname(__FILE__) + '/../test_helper'

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

  def test_report_queues_transactions_to_report
    Transactor.report(
      @provider_key,
      {'0' => {'app_id' => @application_id_one, 'usage' => {'hits' => 1}},
       '1' => {'app_id' => @application_id_two, 'usage' => {'hits' => 1}}})

    assert_queued Transactor::ReportJob,
                  [@service_id,
                    {'0' => {'app_id' => @application_id_one, 'usage' => {'hits' => 1}},
                     '1' => {'app_id' => @application_id_two, 'usage' => {'hits' => 1}}}]
  end
  
  def test_report_raises_an_exception_when_provider_key_is_invalid
    assert_raise ProviderKeyInvalid do
      Transactor.report(
        'booo',
        {'0' => {'app_id' => @application_id_one, 'usage' => {'hits' => 1}}})
    end
  end
  
  def test_report_queues_backend_hit
    Timecop.freeze(Time.utc(2010, 7, 29, 11, 48)) do
      Transactor.report(
        @provider_key,
        '0' => {'app_id' => @application_id_one, 'usage' => {'hits' => 1}},
        '1' => {'app_id' => @application_id_two, 'usage' => {'hits' => 1}})

      assert_queued Transactor::NotifyJob, 
                    [@provider_key, 
                     {'transactions/create_multiple' => 1,
                      'transactions'                 => 2},
                     '2010-07-29 11:48:00 UTC']
    end
  end

  def test_authorize_returns_status_object_with_the_plan_name
    status = Transactor.authorize(@provider_key, @application_id_one)

    assert_not_nil status
    assert_equal @plan_name, status.plan_name
  end

  def test_authorize_returns_status_object_with_usage_reports_if_the_plan_has_usage_limits
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
      status = Transactor.authorize(@provider_key, @application_id_one)
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
  
  def test_authorize_returns_status_object_without_usage_reports_if_the_plan_has_no_usage_limits
    status = Transactor.authorize(@provider_key, @application_id_one)
    assert_equal 0, status.usage_reports.count
  end

  def test_authorize_returns_unauthorized_status_object_when_application_is_suspended
    application = Application.load(@service_id, @application_id_one)
    application.state = :suspended
    application.save

    status = Transactor.authorize(@provider_key, @application_id_one)
    assert !status.authorized?
    assert_equal 'application_not_active',    status.rejection_reason_code
    assert_equal 'application is not active', status.rejection_reason_text
  end
  
  def test_authorize_returns_unauthorized_status_object_when_usage_limits_are_exceeded
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
      status = Transactor.authorize(@provider_key, @application_id_one)
      assert !status.authorized?
      assert_equal 'limits_exceeded',           status.rejection_reason_code
      assert_equal 'usage limits are exceeded', status.rejection_reason_text
    end
  end
  
  def test_authorize_succeeds_if_there_are_usage_limits_that_are_not_exceeded
    UsageLimit.save(:service_id => @service_id, 
                    :plan_id    => @plan_id, 
                    :metric_id  => @metric_id,
                    :day        => 4)

    Timecop.freeze(Time.utc(2010, 5, 14)) do
      Transactor.report(@provider_key, 0 => {'app_id' => @application_id_one,
                                             'usage' => {'hits' => 3}})

      status = Transactor.authorize(@provider_key, @application_id_one)
      assert status.authorized?
    end
  end

  def test_authorize_succeeds_if_no_application_key_is_defined_nor_passed
    status = Transactor.authorize(@provider_key, @application_id_one, nil)
    assert status.authorized?
  end
  
  def test_authorize_succeeds_if_no_application_key_is_defined_and_blank_one_is_passed
    status = Transactor.authorize(@provider_key, @application_id_one, '')
    assert status.authorized?
  end

  def test_authorize_succeeds_if_one_application_key_is_defined_and_the_same_is_passed
    application = Application.load(@service_id, @application_id_one)
    application_key = application.create_key!

    status = Transactor.authorize(@provider_key, @application_id_one, application_key)
    assert status.authorized?
  end
  
  def test_authorize_succeeds_if_multiple_application_keys_are_defined_and_one_of_them_is_passed
    application = Application.load(@service_id, @application_id_one)
    application_key_one = application.create_key!
    application_key_two = application.create_key!

    status = Transactor.authorize(@provider_key, @application_id_one, application_key_one)
    assert status.authorized?
  end

  def test_authorize_returns_unauthorized_status_object_if_application_key_is_defined_but_not_passed
    application = Application.load(@service_id, @application_id_one)
    application.create_key!
    
    status = Transactor.authorize(@provider_key, @application_id_one, nil)

    assert !status.authorized?
    assert_equal 'application_key_invalid',    status.rejection_reason_code
    assert_equal 'application key is missing', status.rejection_reason_text
  end
  
  def test_authorize_returns_unauthorized_status_object_if_invalid_application_key_is_passed
    application = Application.load(@service_id, @application_id_one)
    application.create_key!('foo')
    
    status = Transactor.authorize(@provider_key, @application_id_one, 'bar')

    assert !status.authorized?
    assert_equal 'application_key_invalid',          status.rejection_reason_code
    assert_equal 'application key "bar" is invalid', status.rejection_reason_text
  end
  
  def test_authorize_raises_an_exception_when_provider_key_is_invalid
    assert_raise ProviderKeyInvalid do
      Transactor.authorize('booo', @application_id_one)
    end
  end
  
  def test_authorize_raises_an_exception_when_application_id_is_invalid
    assert_raise ApplicationNotFound do
      Transactor.authorize(@provider_key, 'baaa')
    end
  end
  
  def test_authorize_queues_backend_hit
    Timecop.freeze(Time.utc(2010, 7, 29, 17, 9)) do
      Transactor.authorize(@provider_key, @application_id_one)

      assert_queued Transactor::NotifyJob, 
                    [@provider_key, 
                     {'transactions/authorize' => 1},
                     '2010-07-29 17:09:00 UTC']
    end
  end
end
