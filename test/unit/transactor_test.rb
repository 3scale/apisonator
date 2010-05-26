require File.dirname(__FILE__) + '/../test_helper'

class TransactorTest < Test::Unit::TestCase
  include TestHelpers::EventMachine
  include TestHelpers::MasterService

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    setup_master_service

    @provider_key = 'provider_key'
    @master_contract_id = next_id
    Contract.save(:service_id => @master_service_id,
                  :user_key => @provider_key,
                  :id => @master_contract_id,
                  :state => :live)

    @service_id = next_id
    Core::Service.save(:provider_key => @provider_key, :id => @service_id)

    @metric_id = next_id
    Metric.save(:service_id => @service_id, :id => @metric_id, :name => 'hits')

    @plan_id = next_id
    @plan_name = 'killer'
    
    @contract_id_one = next_id
    @user_key_one = 'user_key1'
    Contract.save(:service_id => @service_id,
                  :user_key => @user_key_one,
                  :id => @contract_id_one,
                  :state => :live,
                  :plan_id => @plan_id,
                  :plan_name => @plan_name)
    
    @contract_id_two = next_id
    @user_key_two = 'user_key2'
    Contract.save(:service_id => @service_id,
                  :user_key => @user_key_two,
                  :id => @contract_id_two,
                  :state => :live,
                  :plan_id => @plan_id,
                  :plan_name => @plan_name)
  end
  
  def test_report_aggregates
    time = Time.now

    Aggregator.expects(:aggregate).with(:service_id  => @service_id,
                                        :contract_id => @contract_id_one,
                                        :timestamp   => time,
                                        :usage       => {@metric_id => 1})

    Aggregator.expects(:aggregate).with(:service_id  => @service_id,
                                        :contract_id => @contract_id_two,
                                        :timestamp   => time,
                                        :usage       => {@metric_id => 1})
    
    Aggregator.stubs(:aggregate).with(has_entry(:service_id => @master_service_id))

    Timecop.freeze(time) do
      Transactor.report(
        @provider_key,
        {'0' => {'user_key' => @user_key_one, 'usage' => {'hits' => 1}},
         '1' => {'user_key' => @user_key_two, 'usage' => {'hits' => 1}}})
    end
  end
  
  def test_report_handles_transactions_with_utc_timestamps
    Aggregator.expects(:aggregate).with(
      has_entry(:timestamp => Time.utc(2010, 5, 7, 18, 11, 25)))
    
    Aggregator.stubs(:aggregate).with(has_entry(:service_id => @master_service_id))

    Transactor.report(@provider_key, 0 => {'user_key' => @user_key_one,
                                           'usage' => {'hits' => 1},
                                           'timestamp' => '2010-05-07 18:11:25'})
  end
  
  def test_report_handles_transactions_with_local_timestamps
    Aggregator.expects(:aggregate).with(
      has_entry(:timestamp => Time.utc(2010, 5, 7, 11, 11, 25)))
    
    Aggregator.stubs(:aggregate).with(has_entry(:service_id => @master_service_id))

    Transactor.report(@provider_key, 0 => {'user_key' => @user_key_one,
                                           'usage' => {'hits' => 1},
                                           'timestamp' => '2010-05-07 18:11:25 +07:00'})
  end

  def test_report_archives
    time = Time.now

    Archiver.expects(:add).with(:service_id  => @service_id,
                                :contract_id => @contract_id_one,
                                :timestamp   => time,
                                :usage       => {@metric_id => 1})

    Archiver.expects(:add).with(:service_id  => @service_id,
                                :contract_id => @contract_id_two,
                                :timestamp   => time,
                                :usage       => {@metric_id => 1})

    Archiver.stubs(:add).with(has_entry(:service_id => @master_service_id))

    Timecop.freeze(time) do
      Transactor.report(
        @provider_key,
        {'0' => {'user_key' => @user_key_one, 'usage' => {'hits' => 1}},
         '1' => {'user_key' => @user_key_two, 'usage' => {'hits' => 1}}})
    end
  end
  
  def test_report_raises_an_exception_when_provider_key_is_invalid
    assert_raise ProviderKeyInvalid do
      Transactor.report(
        'booo',
        {'0' => {'user_key' => @user_key_one, 'usage' => {'hits' => 1}}})
    end
  end
  
  def test_report_raises_an_exception_when_one_user_key_is_invalid
    begin
      Transactor.report(
        @provider_key,
        '0' => {'user_key' => 'invalid',     'usage' => {'hits' => 1}},
        '1' => {'user_key' => @user_key_two, 'usage' => {'hits' => 1}})

      flunk 'Expected MultipleErrors exception, but none raised'

    rescue MultipleErrors => exception
      assert_equal 1, exception.codes.size
      assert_equal 'user.invalid_key', exception.codes[0]
    end
  end
  
  def test_report_raises_an_exception_when_many_user_keys_are_invalid
    begin
      Transactor.report(
        @provider_key,
        '0' => {'user_key' => 'invalid', 'usage' => {'hits' => 1}},
        '1' => {'user_key' => 'invalid', 'usage' => {'hits' => 1}})

      flunk 'Expected MultipleErrors exception, but none raised'

    rescue MultipleErrors => exception
      assert_equal 2, exception.codes.size
      assert_equal 'user.invalid_key', exception.codes[0]
      assert_equal 'user.invalid_key', exception.codes[1]
    end
  end
  
  def test_report_raises_an_exception_when_the_contract_is_not_active
    contract = Contract.load(@service_id, @user_key_one)
    contract.state = :suspended
    contract.save

    begin
      Transactor.report(
        @provider_key,
        '0' => {'user_key' => @user_key_one, 'usage' => {'hits' => 1}},
        '1' => {'user_key' => @user_key_two, 'usage' => {'hits' => 1}})

      flunk 'Expected MultipleErrors exception, but none raised'

    rescue MultipleErrors => exception
      assert_equal 1, exception.codes.size
      assert_equal 'user.inactive_contract', exception.codes[0]
    end
  end
  
  def test_report_raises_an_exception_when_metric_names_in_one_transaction_are_invalid
    begin
      Transactor.report(
        @provider_key,
        '0' => {'user_key' => @user_key_one, 'usage' => {'hits' => 1}},
        '1' => {'user_key' => @user_key_two, 'usage' => {'monkeys' => 1}})

      flunk 'Expected MultipleErrors exception, but none raised'

    rescue MultipleErrors => exception
      assert_equal 1, exception.codes.size
      assert_equal 'provider.invalid_metric', exception.codes[1]
    end
  end
  
  def test_report_raises_an_exception_when_metric_names_in_many_transactions_of_different_contract_are_invalid
    begin
      Transactor.report(
        @provider_key,
        '0' => {'user_key' => @user_key_one, 'usage' => {'penguins' => 1}},
        '1' => {'user_key' => @user_key_two, 'usage' => {'monkeys' => 1}})

      flunk 'Expected MultipleErrors exception, but none raised'

    rescue MultipleErrors => exception
      assert_equal 2, exception.codes.size
      assert_equal 'provider.invalid_metric', exception.codes[0]
      assert_equal 'provider.invalid_metric', exception.codes[1]
    end
  end
  
  def test_report_raises_an_exception_when_metric_names_in_many_transactions_of_the_same_contract_are_invalid
    begin
      Transactor.report(
        @provider_key,
        '0' => {'user_key' => @user_key_one, 'usage' => {'penguins' => 1}},
        '1' => {'user_key' => @user_key_one, 'usage' => {'monkeys' => 1}})

      flunk 'Expected MultipleErrors exception, but none raised'

    rescue MultipleErrors => exception
      assert_equal 2, exception.codes.size
      assert_equal 'provider.invalid_metric', exception.codes[0]
      assert_equal 'provider.invalid_metric', exception.codes[1]
    end
  end
  
  def test_report_raises_an_exception_with_entries_for_invalid_transactions_only
    begin
      Transactor.report(
        @provider_key,
        '0' => {'user_key' => @user_key_one, 'usage' => {'hits' => 1}},
        '1' => {'user_key' => @user_key_one, 'usage' => {'monkeys' => 1}})

      flunk 'Expected MultipleErrors exception, but none raised'

    rescue MultipleErrors => exception
      assert_equal 1, exception.codes.size
      assert_equal 'provider.invalid_metric', exception.codes[1]
    end
  end
  
  def test_report_does_not_aggregate_anything_when_at_least_one_transaction_is_invalid
    Aggregator.expects(:aggregate).with(has_entry(:service_id => @service_id)).never
    Aggregator.stubs(:aggregate).with(has_entry(:service_id => @master_service_id))

    begin
      Transactor.report(
        @provider_key,
        '0' => {'user_key' => 'invalid',     'usage' => {'hits' => 1}},
        '1' => {'user_key' => @user_key_two, 'usage' => {'hits' => 1}})
    rescue MultipleErrors
    end
  end

  def test_report_aggregates_backend_hit
    time = Time.now

    Aggregator.expects(:aggregate).with(
      :service_id  => @master_service_id,
      :contract_id => @master_contract_id,
      :timestamp   => time,
      :usage       => {@master_hits_id => 1,
                       @master_reports_id => 1,
                       @master_transactions_id => 2})

    Aggregator.stubs(:aggregate).with(Not(has_entry(:service_id => @master_service_id)))

    Timecop.freeze(time) do
      Transactor.report(
        @provider_key,
        '0' => {'user_key' => @user_key_one, 'usage' => {'hits' => 1}},
        '1' => {'user_key' => @user_key_two, 'usage' => {'hits' => 1}})
    end
  end
  
  def test_report_archives_backend_hit
    time = Time.now

    Archiver.expects(:add).with(
      :service_id  => @master_service_id,
      :contract_id => @master_contract_id,
      :timestamp   => time,
      :usage       => {@master_hits_id => 1,
                       @master_reports_id => 1,
                       @master_transactions_id => 2})

    Archiver.stubs(:add).with(Not(has_entry(:service_id => @master_service_id)))

    Timecop.freeze(time) do
      Transactor.report(
        @provider_key,
        '0' => {'user_key' => @user_key_one, 'usage' => {'hits' => 1}},
        '1' => {'user_key' => @user_key_two, 'usage' => {'hits' => 1}})
    end
  end

  def test_authorize_returns_object_with_the_plan_name
    status = Transactor.authorize(@provider_key, @user_key_one)

    assert_not_nil status
    assert_equal @plan_name, status.plan_name
  end

  def test_authorize_returns_object_with_usage_status_if_the_plan_has_usage_limits
    UsageLimit.save(:service_id => @service_id, :plan_id => @plan_id, :metric_id => @metric_id,
                    :month => 10000, :day => 200)

    Timecop.freeze(2010, 5, 13) do
      Transactor.report(@provider_key,
                        0 => {'user_key' => @user_key_one, 'usage' => {'hits' => 3}})
    end

    Timecop.freeze(2010, 5, 14) do
      Transactor.report(@provider_key,
                        0 => {'user_key' => @user_key_one, 'usage' => {'hits' => 2}})

      status = Transactor.authorize(@provider_key, @user_key_one)
      assert_equal 2, status.usages.count
    
      usage_month = status.usages.find { |usage| usage.period == :month }
      assert_not_nil usage_month
      assert_equal 'hits', usage_month.metric_name
      assert_equal 5,      usage_month.current_value
      assert_equal 10000,  usage_month.max_value

      usage_day = status.usages.find { |usage| usage.period == :day }
      assert_not_nil usage_day
      assert_equal 'hits', usage_day.metric_name
      assert_equal 2,      usage_day.current_value
      assert_equal 200,    usage_day.max_value
    end
  end
  
  def test_authorize_returns_object_without_usage_status_if_the_plan_has_no_usage_limits
    status = Transactor.authorize(@provider_key, @user_key_one)
    assert_equal 0, status.usages.count
  end
  
  def test_authorize_raises_an_exception_when_provider_key_is_invalid
    assert_raise ProviderKeyInvalid do
      Transactor.authorize('booo', @user_key_one)
    end
  end
  
  def test_authorize_raises_an_exception_when_user_key_is_invalid
    assert_raise UserKeyInvalid do
      Transactor.authorize(@provider_key, 'baaa')
    end
  end
  
  def test_authorize_raises_an_exception_when_contract_is_suspended
    contract = Contract.load(@service_id, @user_key_one)
    contract.state = :suspended
    contract.save

    assert_raise ContractNotActive do
      Transactor.authorize(@provider_key, @user_key_one)
    end
  end

  def test_authorize_raises_an_exception_when_usage_limits_are_exceeded
    UsageLimit.save(:service_id => @service_id, :plan_id => @plan_id, :metric_id => @metric_id,
                    :day => 4)

    Timecop.freeze(Time.utc(2010, 5, 14)) do
      Transactor.report(@provider_key, 0 => {'user_key' => @user_key_one,
                                             'usage' => {'hits' => 5}})

      assert_raise LimitsExceeded do
        Transactor.authorize(@provider_key, @user_key_one)
      end
    end
  end

  def test_authorize_successd_if_there_are_usage_limits_that_are_not_exceeded
    UsageLimit.save(:service_id => @service_id, :plan_id => @plan_id, :metric_id => @metric_id,
                    :day => 4)

    Timecop.freeze(Time.utc(2010, 5, 14)) do
      Transactor.report(@provider_key, 0 => {'user_key' => @user_key_one,
                                             'usage' => {'hits' => 3}})

      assert_not_nil Transactor.authorize(@provider_key, @user_key_one)
    end
  end
  
  def test_authorize_aggregates_backend_hit
    time = Time.now

    Aggregator.expects(:aggregate).with(
      :service_id  => @master_service_id,
      :contract_id => @master_contract_id,
      :timestamp   => time,
      :usage       => {@master_hits_id => 1,
                       @master_authorizes_id => 1})

    Timecop.freeze(time) do
      Transactor.authorize(@provider_key, @user_key_one)
    end
  end
  
  def test_authorize_archives_backend_hit
    time = Time.now

    Archiver.expects(:add).with(
      :service_id  => @master_service_id,
      :contract_id => @master_contract_id,
      :timestamp   => time,
      :usage       => {@master_hits_id => 1,
                       @master_authorizes_id => 1})

    Timecop.freeze(time) do
      Transactor.authorize(@provider_key, @user_key_one)
    end
  end
end
