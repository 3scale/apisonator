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
    done!
  end
  
  def test_successful_report_increments_the_stats_counters
    storage = ThreeScale::Backend.storage

    key = "stats/{service:#{@service.id}}/cinstance:#{@contract.id}/metric:#{@metric.id}/month:20100501"

    storage.get(key) do |response|
      old_value = response.to_i

      post '/transactions.xml',
        :provider_key => @provider_account.api_key,
        :transactions => {0 => {:user_key => @contract.api_key, :usage => {'hits' => 1}}}

      storage.get(key) do |response|
        new_value = response.to_i

        assert_equal 1, new_value - old_value
        done!
      end
    end
  end
end
