require File.dirname(__FILE__) + '/test_helper'

class ReportTest < Test::Unit::TestCase
  def setup
  end

  def test_successful_report_responds_with_200
    post '/transactions.xml',
      'provider_key' => 'foo',
      'transactions' => {'0' => {'user_key' => 'bar', 'usage' => {'hits' => 1}}}

    assert_equal 200, last_response.status
  end
end
