require File.dirname(__FILE__) + '/../test_helper'

# Use the HUGE_PAYLOAD_SIZE env variable to define the size of the payload (number of transaction in it). Default is 10000.

class HugePayloadTest < Test::Unit::TestCase
  include TestHelpers::Integration
  include TestHelpers::MasterService

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    setup_master_service

    @master_contract_id = next_id
    @provider_key = 'provider_key'
    Contract.save(:id         => @master_contract_id,
                  :service_id => @master_service_id, 
                  :user_key   => @provider_key,
                  :state      => :live)

    @service_id = next_id
    Core::Service.save(:provider_key => @provider_key, :id => @service_id)

    @contract_id = next_id
    @user_key = 'user_key'
    @plan_id = next_id
    Contract.save(:id         => @contract_id,
                  :service_id => @service_id, 
                  :plan_id    => @plan_id, 
                  :user_key   => @user_key, 
                  :state      => :live)

    @metric_id = next_id
    Metric.save(:service_id => @service_id, :id => @metric_id, :name => 'hits')
  end

  def test_report_handles_huge_payloads
    payload = generate_payload((ENV['HUGE_PAYLOAD_SIZE'] || 10000).to_i)

    post '/transactions.xml', {}, :input           => payload, 
                                  'CONTENT_TYPE'   => 'application/x-www-form-urlencoded',
                                  'CONTENT_LENGTH' => payload.bytesize

    assert_equal 200, last_response.status
  end

  private

  def generate_payload(transactions_count)
    result = ""
    result << "provider_key=#{@provider_key}"

    transactions_count.times do |index|
      result << "&transactions[#{index}][user_key]=#{@user_key}"
      result << "&transactions[#{index}][usage][hits]=1"
    end

    result
  end
end
