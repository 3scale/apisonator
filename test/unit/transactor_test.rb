require File.dirname(__FILE__) + '/../test_helper'

class TransactorTest < Test::Unit::TestCase
  include TestHelpers::EventMachine

  def setup
    @provider_key = 'key0001'
    @service_id = 1
    @metric_id  = 2001

    @contract_one_id = 1001
    @contract_two_id = 1002

    @user_key_one = 'key1001'
    @user_key_two = 'key1002'
    
    @storage = ThreeScale::Backend.storage
    @storage.flushdb

    @storage.set("service_id/provider_key:#{@provider_key}", @service_id)
  end
  
  def test_report_increments_stats_counters
    assert_change_in_stats :for => @contract_one_id, :by => 1 do
      assert_change_in_stats :for => @contract_two_id, :by => 1 do
        Transactor.report(
          @provider_key,
          {'0' => {:user_key => @user_key_one, :usage => {'hits' => 1}},
           '1' => {:user_key => @user_key_two, :usage => {'hits' => 1}}})
      end
    end
  end

  private

  def assert_change_in_stats(options, &block)
    contract_id = options.delete(:for)
    key = "stats/{service:#{@service_id}}/cinstance:#{contract_id}/metric:#{@metric_id}/eternity"

    options = options.dup
    options[:of] = lambda { @storage.get(key).to_i }

    assert_change options, &block
  end

  # def test_raises_an_exception_if_provider_key_is_invalid
  #   assert_raise ProviderKeyInvalid do
  #     Transactor.report(:provider_key => 'booo',
  #                       :transactions => {'0' => {'user_key' => @user_key_one,
  #                                                 'usage' => {'hits' => 1}}})
  #   end
  # end


  # test 'asynchronously aggregates the transactions' do
  #   Worker.expects(:asynch_aggregate).
  #     with(has_entries(:cinstance => @cinstance_one.id,
  #                      :usage => NumericHash.new(@metric.id => 1)))

  #   Worker.expects(:asynch_aggregate).
  #     with(has_entries(:cinstance => @cinstance_two.id,
  #                      :usage => NumericHash.new(@metric.id => 1)))

  #   Transaction.report_multiple!(
  #     @provider_account.id,
  #     '0' => {:user_key => @user_key_one, :usage => {'hits' => 1}},
  #     '1' => {:user_key => @user_key_two, :usage => {'hits' => 1}})
  # end

  # test 'reports transactions with timestamps in UTC' do
  #   time_utc   = Time.use_zone('UTC') { time(2009, 7, 18, 11, 25) }
  #   time_local = time_utc.in_time_zone(Time.zone)

  #   assert_change_in_usage :cinstance => @cinstance_one,
  #                          :period => :minute,
  #                          :since => time_local,
  #                          :by => 1 do
  #     Transaction.report_multiple!(
  #       @provider_account.id,
  #       0 => {:user_key => @user_key_one, :usage => {'hits' => 1},
  #             :timestamp => '2009-07-18 11:25'})
  #   end
  # end

  # test 'reports transactions with timestamps in local time' do
  #   time_zone  = ActiveSupport::TimeZone[8.hours]
  #   time_there = Time.use_zone(time_zone) { time(2009, 7, 18, 11, 25) }
  #   time_here  = time_there.in_time_zone(Time.zone)

  #   assert_change_in_usage :cinstance => @cinstance_one,
  #                          :period => :minute,
  #                          :since => time_here,
  #                          :by => 1 do
  #     Transaction.report_multiple!(
  #       @provider_account.id,
  #       0 => {:user_key => @user_key_one, :usage => {'hits' => 1},
  #             :timestamp => time_there.to_s})
  #   end
  # end

  # test 'reports transactions even when they exceed limits' do
  #   4.times do
  #     Transaction.report!(:cinstance => @cinstance_one,
  #                         :usage => {'hits' => 1})
  #   end

  #   @plan.usage_limits.create!(:metric => @metric, :value => 4, :period => :month)

  #   assert_change_in_usage :cinstance => @cinstance_one, :by => 2 do
  #     Transaction.report_multiple!(
  #       @provider_account.id,
  #       '0' => {:user_key => @user_key_one, :usage => {'hits' => 1}},
  #       '1' => {:user_key => @user_key_one, :usage => {'hits' => 1}})
  #   end
  # end

  # context 'with pricing rules' do
  #   setup do
  #     set_billing_mode(@provider_account, :prepaid)

  #     @plan.pricing_rules.create!(:metric => @metric, :cost_per_unit => 0.1)
  #     @buyer_account_one.update_attribute(:buyerbalance, 100)
  #     @buyer_account_two.update_attribute(:buyerbalance, 100)
  #   end

  #   should 'update balances of provider and buyers' do
  #     assert_difference '@buyer_account_one.buyerbalance', -0.2 do
  #       assert_difference '@buyer_account_two.buyerbalance', -0.1 do
  #         assert_difference '@provider_account.providerbalance', 0.3 do
  #           Transaction.report_multiple!(
  #             @provider_account.id,
  #             '0' => {:user_key => @user_key_one, :usage => {'hits' => 1}},
  #             '1' => {:user_key => @user_key_one, :usage => {'hits' => 1}},
  #             '2' => {:user_key => @user_key_two, :usage => {'hits' => 1}})

  #           @provider_account.reload
  #           @buyer_account_one.reload
  #           @buyer_account_two.reload
  #         end
  #       end
  #     end
  #   end

  #   should 'pay the cost asynchronously' do
  #     Worker.expects(:asynch_pay).
  #       with(:cinstance_id => @cinstance_one.id,
  #            :cost => NumericHash.new(@metric.id => 0.2),
  #            :usage => NumericHash.new(@metric.id => 2))

  #     Transaction.report_multiple!(
  #       @provider_account.id,
  #       '0' => {:user_key => @user_key_one, :usage => {'hits' => 1}},
  #       '1' => {:user_key => @user_key_one, :usage => {'hits' => 1}})
  #   end
  # end

  # test 'raises MultipleErrors exception when one user key is invalid' do
  #   begin
  #     Transaction.report_multiple!(
  #       @provider_account.id,
  #       '0' => {:user_key => 'invalid', :usage => {'hits' => 1}},
  #       '1' => {:user_key => @user_key_two, :usage => {'hits' => 1}})

  #     flunk 'Expected MultipleErrors exception, but none raised'

  #   rescue MultipleErrors => exception
  #     assert_equal 1, exception.codes.size
  #     assert_equal 'user.invalid_key', exception.codes[0]
  #   end
  # end

  # test 'raises MultipleErrors exception when many user keys are invalid' do
  #   begin
  #     Transaction.report_multiple!(
  #       @provider_account.id,
  #       '0' => {:user_key => 'invalid', :usage => {'hits' => 1}},
  #       '1' => {:user_key => 'invalid', :usage => {'hits' => 1}})

  #     flunk 'Expected MultipleErrors exception, but none raised'

  #   rescue MultipleErrors => exception
  #     assert_equal 2, exception.codes.size
  #     assert_equal 'user.invalid_key', exception.codes[0]
  #     assert_equal 'user.invalid_key', exception.codes[1]
  #   end
  # end

  # test 'raises MultipleErrors exception when the cinstance is not live' do
  #   @cinstance_one.suspend!

  #   begin
  #     Transaction.report_multiple!(
  #       @provider_account.id,
  #       '0' => {:user_key => @user_key_one, :usage => {'hits' => 1}},
  #       '1' => {:user_key => @user_key_two, :usage => {'hits' => 1}})

  #     flunk 'Expected MultipleErrors exception, but none raised'

  #   rescue MultipleErrors => exception
  #     assert_equal 1, exception.codes.size
  #     assert_equal 'user.inactive_contract', exception.codes[0]
  #   end
  # end

  # test 'raises MultipleErrors exception when metric names of one transaction are invalid' do
  #   begin
  #     Transaction.report_multiple!(
  #       @provider_account.id,
  #       '0' => {:user_key => @user_key_one, :usage => {'hits' => 1}},
  #       '1' => {:user_key => @user_key_two, :usage => {'monkeys' => 1}})

  #     flunk 'Expected MultipleErrors exception, but none raised'

  #   rescue MultipleErrors => exception
  #     assert_equal 1, exception.codes.size
  #     assert_equal 'provider.invalid_metric', exception.codes[1]
  #   end
  # end

  # test 'raises MultipleErrors exception when metric names of many transaction of different cinstances are invalid' do
  #   begin
  #     Transaction.report_multiple!(
  #       @provider_account.id,
  #       '0' => {:user_key => @user_key_one, :usage => {'penguins' => 1}},
  #       '1' => {:user_key => @user_key_two, :usage => {'monkeys' => 1}})

  #     flunk 'Expected MultipleErrors exception, but none raised'

  #   rescue MultipleErrors => exception
  #     assert_equal 2, exception.codes.size
  #     assert_equal 'provider.invalid_metric', exception.codes[0]
  #     assert_equal 'provider.invalid_metric', exception.codes[1]
  #   end
  # end

  # test 'raises MultipleErrors exception when metric names of many transaction of the same cinstance are invalid' do
  #   begin
  #     Transaction.report_multiple!(
  #       @provider_account.id,
  #       '0' => {:user_key => @user_key_one, :usage => {'penguins' => 1}},
  #       '1' => {:user_key => @user_key_one, :usage => {'monkeys' => 1}})

  #     flunk 'Expected MultipleErrors exception, but none raised'

  #   rescue MultipleErrors => exception
  #     assert_equal 2, exception.codes.size
  #     assert_equal 'provider.invalid_metric', exception.codes[0]
  #     assert_equal 'provider.invalid_metric', exception.codes[1]
  #   end
  # end

  # test 'raises MultipleErrors exception with only indices of invalid transactions when metric names are invalid' do
  #   begin
  #     Transaction.report_multiple!(
  #       @provider_account.id,
  #       '0' => {:user_key => @user_key_one, :usage => {'hits' => 1}},
  #       '1' => {:user_key => @user_key_one, :usage => {'monkeys' => 1}})

  #     flunk 'Expected MultipleErrors exception, but none raised'

  #   rescue MultipleErrors => exception
  #     assert_equal 1, exception.codes.size
  #     assert_equal 'provider.invalid_metric', exception.codes[1]
  #   end
  # end

  # test 'does not process valid transaction if at least one transaction is invalid' do
  #   assert_no_change_in_usage :cinstance => @cinstance_two do
  #     begin
  #       Transaction.report_multiple!(
  #         @provider_account.id,
  #         '0' => {:user_key => 'invalid', :usage => {'hits' => 1}},
  #         '1' => {:user_key => @user_key_two, :usage => {'hits' => 1}})
  #     rescue MultipleErrors
  #     end
  #   end
  # end

end
