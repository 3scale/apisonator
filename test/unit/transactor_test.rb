require File.dirname(__FILE__) + '/../test_helper'

class TransactorTest < Test::Unit::TestCase
  include TestHelpers::EventMachine

  def setup
    @provider_account = Factory(:provider_account)
    @service = Factory(:service, :account => @provider_account)
    @plan = Factory(:plan, :service => @service)
    @metric = @service.metrics.hits

    @buyer_account_one = Factory(:buyer_account, :provider_account => @provider_account)
    @buyer_account_two = Factory(:buyer_account, :provider_account => @provider_account)

    @contract_one = Factory(:contract, :plan => @plan, :buyer_account => @buyer_account_one)
    @contract_two = Factory(:contract, :plan => @plan, :buyer_account => @buyer_account_two)

    @user_key_one = @contract_one.user_key
    @user_key_two = @contract_two.user_key

    @storage = ThreeScale::Backend.storage
    @storage.flushdb
  end
  
  def test_report_increments_stats_counters
    @storage.get(storage_key(@contract_one)) do |response|
      old_value_one = response.to_i

      @storage.get(storage_key(@contract_two)) do |response|
        old_value_two = response.to_i

        Transactor.report(
          :provider_key => @provider_account.api_key,
          :transactions => {
            '0' => {:user_key => @user_key_one, :usage => {'hits' => 1}},
            '1' => {:user_key => @user_key_two, :usage => {'hits' => 1}}}) do

          @storage.get(storage_key(@contract_one)) do |response|
            new_value_one = response.to_i

            @storage.get(storage_key(@contract_two)) do |response|
              new_value_two = response.to_i

              assert_equal 1, new_value_one - old_value_one
              assert_equal 1, new_value_two - old_value_two
              done!
            end
          end
        end
      end
    end
  end

  private

  def storage_key(contract)
    "stats/{service:#{@service.id}}/cinstance:#{contract.id}/metric:#{@metric.id}/eternity"
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
