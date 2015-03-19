require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require_relative '../../lib/3scale/backend/stats/tasks'

class AggregatorResponseCodesTest < Test::Unit::TestCase

  include TestHelpers::Fixtures

  def default_transaction_with_response_code
    trans = default_transaction
    trans.response_code = 404
    trans
  end

  def default_transaction_with_response_code_and_user
    trans = default_transaction_with_response_code
    trans.user_id = 123
    trans
  end

  def setup
    @transaction = default_transaction_with_response_code
    @transaction_with_user = default_transaction_with_response_code_and_user
  end

  test 'trans' do
    k = Stats::Aggregator.send :aggregate_response_codes, @transaction, nil
    assert_equal [:application, :service], k.keys.sort
    k = Stats::Aggregator.send :aggregate_response_codes, @transaction_with_user, nil
    assert_equal [:application, :service, :user], k.keys.sort
  end
end
