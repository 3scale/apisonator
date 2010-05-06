require File.dirname(__FILE__) + '/../test_helper'

class ReportTest < Test::Unit::TestCase
  include TestHelpers::Integration
  include TestHelpers::EventMachine

  def setup
    @contract = Factory(:contract)
    @service = @contract.service
    @metric = @service.metrics.hits

    @provider_account = @service.account
  end

  def test_successful_report_responds_with_200
    post '/transactions.xml',
      :provider_key => @provider_account.api_key,
      :transactions => {0 => {:user_key => @contract.api_key, :usage => {'hits' => 1}}}

    assert_equal 200, last_response.status
  end
  
  def test_successful_report_increments_the_stats_counters
    storage = ThreeScale::Backend.storage

    key = "stats/{service:#{@service.id}}/cinstance:#{@contract.id}/metric:#{@metric.id}/month:20100501"

    assert_change :of => lambda { storage.get(key).to_i }, :by => 1 do
      post '/transactions.xml',
        :provider_key => @provider_account.api_key,
        :transactions => {0 => {:user_key => @contract.api_key, :usage => {'hits' => 1}}}
    end
  end
end
