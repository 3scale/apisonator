require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Transactor
  class ProcessJobTest < Test::Unit::TestCase
    include TestHelpers::Sequences

    def setup
      @provider_key       = next_id
      @service_id         = next_id
      @application_id_one = next_id
      @application_id_two = next_id
      @metric_id          = next_id

      Service.save!(provider_key: @provider_key, id: @service_id)

      Application.save(service_id: @service_id,
                       id:         @application_id_one,
                       state:      :live)

      Application.save(service_id: @service_id,
                       id:         @application_id_two,
                       state:      :live)

      # Create metrics
      Metric.save(service_id: @service_id, id: @metric_id, name: @metric_id)
    end

    def default_transaction_attributes
      {
        'service_id'     => @service_id,
        'application_id' => @application_id_one,
        'usage'          => { @metric_id => 1 },
      }
    end

    def test_aggregates
      transaction_time = Time.utc(2010, 7, 25, 14, 4, 0)
      current_time = transaction_time + 30

      Timecop.freeze(current_time) do
        Stats::Aggregator.expects(:process).with do |transactions|
          transactions.all? do |t|
            t.is_a?(Transaction) && t.timestamp == transaction_time
          end
          transactions.first.application_id == @application_id_one
          transactions.last.application_id  == @application_id_two
        end

        Transactor::ProcessJob.perform(
            [default_transaction_attributes.merge('timestamp' => transaction_time.to_s),
             default_transaction_attributes.merge('application_id' => @application_id_two,
                                                  'timestamp' => transaction_time.to_s)])
      end
    end

    def test_handles_transactions_with_utc_timestamps
      transaction_time = Time.utc(2010, 5, 7, 18, 11, 25)
      current_time = transaction_time + 30

      Timecop.freeze(current_time) do
        Stats::Aggregator.expects(:process).with do |transactions|
          transactions.first.timestamp == transaction_time
        end

        Transactor::ProcessJob.perform(
          [default_transaction_attributes.merge('timestamp' => transaction_time.to_s)])
      end
    end

    def test_handles_transactions_with_local_timestamps
      transaction_time = Time.parse('2010-05-06 19:11:20 +07:00')
      current_time = transaction_time + 30

      Timecop.freeze(current_time) do
        Stats::Aggregator.expects(:process).with do |transactions|
          transactions.first.timestamp == transaction_time.utc
        end

        Transactor::ProcessJob.perform(
          [default_transaction_attributes.merge('timestamp' => transaction_time.to_s)])
      end
    end

    def test_handles_transactions_with_blank_timestamps
      timestamp = ''
      current_time = Time.utc(2016, 1, 26, 9, 30, 20)

      Timecop.freeze(current_time) do
        Stats::Aggregator.expects(:process).with do |transactions|
          transactions.first.timestamp == current_time
        end

        Transactor::ProcessJob.perform(
          [default_transaction_attributes.merge('timestamp' => timestamp)])
      end
    end
  end
end
