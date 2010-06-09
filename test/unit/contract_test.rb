require File.dirname(__FILE__) + '/../test_helper'

class ContractTest < Test::Unit::TestCase
  def test_live_returns_true_if_contract_has_no_state_set
    contract = Contract.new(:state => nil)
    assert contract.live?
  end
  
  def test_live_returns_true_if_contract_is_in_live_state
    contract = Contract.new(:state => :live)
    assert contract.live?
  end

  def test_live_returns_false_if_contract_is_in_suspended_state
    contract = Contract.new(:state => :suspended)
    assert !contract.live?
  end
end
