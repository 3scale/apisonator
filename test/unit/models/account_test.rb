require File.dirname(__FILE__) + '/../../test_helper'

class AccountTest < Test::Unit::TestCase
  include TestHelpers::EventMachine

  def test_id_by_api_key_raises_an_exception_if_the_key_is_invalid
    assert_raise ApiKeyInvalid do
      Account.id_by_api_key('boo')
    end
  end

  def test_id_by_api_key_finds_account_id_by_api_key_of_the_bought_contract
    plan = Factory(:plan)
    account = Factory(:buyer_account, :provider_account => plan.provider_account)
    contract = Factory(:contract, :plan => plan, :buyer_account => account)

    assert_equal account.id, Account.id_by_api_key(contract.api_key)
  end

  def test_id_by_api_key_stores_the_found_id_in_the_storage_for_faster_future_access
  end
end
