require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class TransactorTest < Test::Unit::TestCase
  include TestHelpers::Fixtures

  include TestHelpers::AuthRep

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!

    setup_oauth_provider_fixtures

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

    @context_info = {}
    @raw_transactions = {
      '0' => {
        'app_id' => @application_one.id,
        'usage'  => { 'hits' => 1 },
      },
      '1' => {
        'app_id' => @application_two.id,
        'usage'  => { 'hits' => 1 },
      },
    }
  end

  test 'report queues transactions to report' do
    Timecop.freeze(Time.utc(2011, 12, 12, 11, 48)) do
      Transactor.report(@provider_key, nil, @raw_transactions)

      assert_queued Transactor::ReportJob,
                    [@service_id,
                     @raw_transactions,
                     Time.utc(2011, 12, 12, 11, 48).to_f,
                     @context_info]
    end
  end

  test 'report queues transactions to report with explicit service id' do
    Timecop.freeze(Time.utc(2011, 12, 12, 11, 48)) do
      Transactor.report(@provider_key, @service_id, @raw_transactions)

      assert_queued Transactor::ReportJob,
                    [@service_id,
                     @raw_transactions,
                     Time.utc(2011, 12, 12, 11, 48).to_f,
                     @context_info]
    end
  end

  test 'report raises ProviderKeyInvalidOrServiceMissing when provider key is invalid and no service ID is given' do
    assert_raise ProviderKeyInvalidOrServiceMissing do
      Transactor.report('booo', nil, Hash[*@raw_transactions.first])
    end
  end

  test 'report raises ServiceIdInvalid when both the provider key and the service are invalid' do
    assert_raise ServiceIdInvalid do
      Transactor.report('booo', 'non_existing_service', Hash[*@raw_transactions.first])
    end
  end

  test 'report raises ProviderKeyInvalidOrServiceMissing when provider key has no default service and a service id is not given' do
    setup_provider_without_default_service

    assert_raise ProviderKeyInvalidOrServiceMissing do
      Transactor.report(@provider_key_without_default_service,
                        nil, Hash[*@raw_transactions.first])
    end
  end

  test 'report raises an exception when provider key is invalid even with a valid service id' do
    assert_raise ProviderKeyInvalid do
      Transactor.report('booo', @service_id, Hash[*@raw_transactions.first])
    end
  end

  test 'report queues backend hit' do
    Timecop.freeze(Time.utc(2010, 7, 29, 11, 48)) do
      Transactor.report(@provider_key, nil, @raw_transactions)

      ## processes all the pending notifyjobs.
      Transactor.process_full_batch

      assert_queued Transactor::NotifyJob,
                    [@provider_key,
                     { 'transactions' => 2 },
                     '2010-07-29 11:48:00 UTC',
                     Time.utc(2010, 7, 29, 11, 48).to_f]
    end
  end

  test 'report queues backend hit with explicit service id' do
    Timecop.freeze(Time.utc(2010, 7, 29, 11, 48)) do
      Transactor.report(@provider_key, @service_id, @raw_transactions)

      ## processes all the pending notifyjobs.
      Transactor.process_full_batch

      assert_queued Transactor::NotifyJob,
                    [@provider_key,
                     { 'transactions' => 2 },
                     '2010-07-29 11:48:00 UTC',
                     Time.utc(2010, 7, 29, 11, 48).to_f]
    end
  end

  test 'report does not include usages of 0 when it generates a report job' do
    current_time = Time.now

    metric_name = 'some_metric'
    Metric.save(service_id: @service_id, id: next_id, name: metric_name)

    transactions = {
      '0' => {
        app_id: @application_one.id,
        usage: { 'hits' => 0, metric_name => 1 },
        timestamp: current_time
      },
      '1' => {
        app_id: @application_two.id,
        usage: { 'hits' => 0, metric_name => 2 },
        timestamp: current_time
      }
    }

    Timecop.freeze(current_time) do
      Transactor.report(@provider_key, @service_id, transactions)
    end

    # "hits" should not appear because it has a usage of 0.
    transactions.each do |_idx, tx| tx[:usage].delete('hits') end

    assert_queued(
      Transactor::ReportJob,
      [@service_id, transactions, current_time.to_f, @context_info]
    )
  end

  test 'report includes usages with "set to 0" (#0) when it generates a report job' do
    current_time = Time.now

    transactions = {
      '0' => {
        app_id: @application_one.id,
        usage: { 'hits' => '#0' },
        timestamp: current_time
      }
    }

    Timecop.freeze(current_time) do
      Transactor.report(@provider_key, @service_id, transactions)
    end

    assert_queued(
      Transactor::ReportJob,
      [@service_id, transactions, current_time.to_f, @context_info]
    )
  end

  test 'report does not enqueue a job if there is not at least a transaction with usage != 0' do
    transactions = {
      '0' => {
        app_id: @application_one.id,
        usage: { 'hits' => 0 },
        timestamp: Time.now
      }
    }

    assert_nothing_queued do
      Transactor.report(@provider_key, @service_id, transactions)
    end
  end

  test 'authorize returns status object with the plan name' do
    status = Transactor.authorize(@provider_key, :app_id => @application_one.id)

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
      Transactor.report(@provider_key, nil,
                        0 => {'app_id' => @application_one.id,
                              'usage'  => {'hits' => 3}})
      Resque.run!
      ## processes all the pending notifyjobs that. This creates a NotifyJob with the
      ## aggregate and another Resque.run! is needed
      Transactor.process_full_batch
      Resque.run!
    end

    Timecop.freeze(Time.utc(2010, 5, 14)) do
      Transactor.report(@provider_key, @service_id,
                        0 => {'app_id' => @application_one.id,
                              'usage'  => {'hits' => 2}})
      Resque.run!
      ## processes all the pending notifyjobs that. This creates a NotifyJob with the
      ## aggregate and another Resque.run! is needed
      Transactor.process_full_batch
      Resque.run!
    end

    Timecop.freeze(Time.utc(2010, 5, 14)) do
      status = Transactor.authorize(@provider_key, :app_id => @application_one.id)

      assert_equal 2, status.application_usage_reports.count

      report_month = status.application_usage_reports.find { |report| report.period == :month }
      assert_not_nil       report_month
      assert_equal 'hits', report_month.metric_name
      assert_equal 5,      report_month.current_value
      assert_equal 10000,  report_month.max_value

      report_day = status.application_usage_reports.find { |report| report.period == :day }
      assert_not_nil       report_day
      assert_equal 'hits', report_day.metric_name
      assert_equal 2,      report_day.current_value
      assert_equal 200,    report_day.max_value
    end
  end

  test 'report raises an exception when invalid provider_key and service_id' do
    assert_raise ServiceIdInvalid do
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
    status = Transactor.authorize(@provider_key, :app_id => @application_one.id)
    assert_equal 0, status.application_usage_reports.count
  end

  test 'authorize raises ProviderKeyInvalidOrServiceMissing when provider key is invalid and no service ID is given' do
    assert_raise ProviderKeyInvalidOrServiceMissing do
      Transactor.authorize('booo', app_id: @application_one.id)
    end
  end

  test 'authorize raises ServiceIdInvalid when both the provider key and the service are invalid' do
    assert_raise ServiceIdInvalid do
      Transactor.authorize('booo', service_id: 'invalid', app_id: @application_one.id)
    end
  end

  test 'authorize raises ProviderKeyInvalidOrServiceMissing when provider key has no default service and a service id is not given' do
    setup_provider_without_default_service

    assert_raise ProviderKeyInvalidOrServiceMissing do
      Transactor.authorize(@provider_key_without_default_service, app_id: @application_one.id)
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
      Transactor.process_full_batch

      assert_queued Transactor::NotifyJob,
                    [@provider_key,
                     {'transactions/authorize' => 1},
                     '2010-07-29 17:09:00 UTC',
                     Time.utc(2010, 7, 29, 17, 9).to_f]
    end
  end

  test 'authorize raises ServiceIdInvalid when the service exists but in other provider' do
    diff_provider_key = next_id
    service = Service.save!(:provider_key => diff_provider_key, :id => next_id)

    assert_raise ServiceIdInvalid do
      Transactor.authorize(@provider_key, :service_id => service.id)
    end
  end

  test 'oauth_authorize raises ServiceIdInvalid when the service exists but in other provider' do
    diff_provider_key = next_id
    service = Service.save!(:provider_key => diff_provider_key, :id => next_id)

    assert_raise ServiceIdInvalid do
      Transactor.oauth_authorize(@provider_key, :service_id => service.id)
    end
  end

  test_authrep 'returns status object without usage reports if the plan has no usage limits' do |_, method|
    status = Transactor.send(method, @provider_key, :app_id => @application_one.id)
    assert_equal 0, status.application_usage_reports.count
  end

  test_authrep 'raises ProviderKeyInvalidOrServiceMissing when provider key is invalid and no service ID is given' do |_, method|
    assert_raise ProviderKeyInvalidOrServiceMissing do
      Transactor.send(method, 'booo', app_id: @application_one.id)
    end
  end

  test_authrep 'raises ServiceIdInvalid when both the provider key and the service are invalid' do |_, method|
    assert_raise ServiceIdInvalid do
      Transactor.send(method, 'booo', service_id: 'invalid', app_id: @application_one.id)
    end
  end

  test_authrep 'raises ProviderKeyInvalidOrServiceMissing when provider key has no default service and a service id is not given' do |_, method|
    setup_provider_without_default_service

    assert_raise ProviderKeyInvalidOrServiceMissing do
      Transactor.send(method, @provider_key_without_default_service, app_id: @application_one.id)
    end
  end

  test_authrep 'raises an exception when application id is invalid' do |_, method|
    assert_raise ApplicationNotFound do
      Transactor.send(method, @provider_key, :app_id => 'baaa')
    end
  end

  test_authrep 'raises an exception when application id is missing' do |_, method|
    assert_raise ApplicationNotFound do
      Transactor.send(method, @provider_key, {})
    end
  end

  test_authrep 'raises an exception when both application id and legacy user key are passed' do |_, method|
    user_key = 'foobar'
    Application.save_id_by_key(@service_id, user_key, @application_one.id)

    assert_raise AuthenticationError do
      Transactor.send(method, @provider_key, :app_id => @application_one.id,
                      :user_key => user_key)
    end
  end

  test_authrep 'queues backend hit' do |_, method|
    Timecop.freeze(Time.utc(2010, 7, 29, 17, 9)) do
      Transactor.send(method, @provider_key, :app_id => @application_one.id)

      ## processes all the pending notifyjobs.
      Transactor.process_full_batch

      assert_queued Transactor::NotifyJob,
        [@provider_key,
         {'transactions/authorize' => 1},
         '2010-07-29 17:09:00 UTC',
         Time.utc(2010, 7, 29, 17, 9).to_f]
    end
  end

  # OAuth is supposed to not support user_key at all, and we already have
  # tests covering that in test/integration/oauth/legacy_test.rb
  test_authrep 'works with legacy user key', except: :oauth_authrep do |_, method|
    user_key = 'foobar'
    Application.save_id_by_key(@service_id, user_key, @application_one.id)

    assert_not_nil Transactor.send(method, @provider_key, :user_key => user_key)
  end

  test_authrep 'raises an exception when legacy user key is invalid',
               except: :oauth_authrep do |_, method|
    Application.save_id_by_key(@service_id, 'foobar', @application_one.id)

    assert_raise UserKeyInvalid do
      Transactor.send(method, @provider_key, :user_key => 'eatthis')
    end
  end

  test_authrep 'raises ServiceIdInvalid when service exists but in other provider' do |_, method|
    diff_provider_key = next_id
    service = Service.save!(:provider_key => diff_provider_key, :id => next_id)

    assert_raise ServiceIdInvalid do
      Transactor.send(method, @provider_key, :service_id => service.id)
    end
  end

  test_authrep 'does not include usages of 0 when it generates a report job' do |_ , method|
    current_time = Time.now
    metric_name = 'some_metric'
    Metric.save(service_id: @service_id, id: next_id, name: metric_name)

    Timecop.freeze(current_time) do
      Transactor.send(
        method,
        @provider_key,
        service_id: @service_id,
        app_id: @application_one.id,
        usage: { 'hits' => 0, metric_name => 1},
        timestamp: current_time
      )
    end

    assert_queued(
      Transactor::ReportJob,
      [
        @service_id,
        # Notice that 'Hits' does not appear because it had a usage of 0
        { 0 => { 'app_id' => @application_one.id, 'usage' => { metric_name => 1}, 'log' => nil } },
        current_time.to_f,
        { 'request' => { 'extensions' => nil } }
      ]
    )
  end

  test_authrep 'includes usages with "set to 0" (#0) when it generates a report job' do |_ , method|
    current_time = Time.now

    Timecop.freeze(current_time) do
      Transactor.send(
        method,
        @provider_key,
        service_id: @service_id,
        app_id: @application_one.id,
        usage: { 'hits' => '#0' },
        timestamp: current_time
      )
    end

    assert_queued(
      Transactor::ReportJob,
      [
        @service_id,
        { 0 => { 'app_id' => @application_one.id, 'usage' => { 'hits' => '#0' }, 'log' => nil } },
        current_time.to_f,
        { 'request' => { 'extensions' => nil } }
      ]
    )
  end

  test_authrep 'does not enqueue a report job if there is not a metric with usage != 0' do |_, method|
    Transactor.send(
      method,
      @provider_key,
      service_id: @service_id,
      app_id: @application_one.id,
      usage: { 'hits' => 0 },
      timestamp: Time.now
    )

    assert_empty Resque.queues[:priority]
  end
end
