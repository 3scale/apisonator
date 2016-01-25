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
        'timestamp'      => '2010-07-26 12:05:00',
        'usage'          => { @metric_id => 1 },
      }
    end

    def test_aggregates
      Timecop.freeze(Time.utc(2010, 7, 25, 14, 5)) do
        Stats::Aggregator.expects(:process).with do |transactions|
          transactions.all? do |t|
            t.is_a?(Transaction) && t.timestamp == Time.utc(2010, 7, 26, 12, 5)
          end
          transactions.first.application_id == @application_id_one
          transactions.last.application_id  == @application_id_two
        end

        Transactor::ProcessJob.perform([default_transaction_attributes,
                                        default_transaction_attributes.merge(
                                          'application_id' => @application_id_two,
                                        )])
      end
    end

    def test_stores
      timestamp = '2010-09-10 16:49:00'

      Timecop.freeze(Time.utc(2010, 9, 10, 00, 00)) do
        TransactionStorage.expects(:store_all).with do |transactions|
          transactions.all? do |t|
            t.is_a?(Transaction) && t.timestamp == Time.utc(2010, 9, 10, 16, 49)
          end
        end

        Transactor::ProcessJob.perform(
          [default_transaction_attributes.merge('timestamp' => timestamp)]
        )
      end
    end

    def test_handles_transactions_with_utc_timestamps
      timestamp = '2010-05-07 18:11:25'

      Timecop.freeze(Time.utc(2010, 5, 7, 17, 12, 25)) do
        Stats::Aggregator.expects(:process).with do |transactions|
          transactions.first.timestamp == Time.utc(2010, 5, 7, 18, 11, 25)
        end

        Transactor::ProcessJob.perform(
          [default_transaction_attributes.merge('timestamp' => timestamp)]
        )
      end
    end

    def test_handles_transactions_with_local_timestamps
      timestamp = '2010-05-07 18:11:25 +07:00'

      Timecop.freeze(Time.utc(2010, 5, 6, 12, 11, 25)) do
        Stats::Aggregator.expects(:process).with do |transactions|
          transactions.first.timestamp == Time.utc(2010, 5, 7, 11, 11, 25)
        end

        Transactor::ProcessJob.perform(
          [default_transaction_attributes.merge('timestamp' => timestamp)]
        )
      end
    end

    def test_handles_transactions_with_blank_timestamps
      timestamp = ''

      Timecop.freeze(Time.utc(2010, 8, 19, 11, 43)) do
        Stats::Aggregator.expects(:process).with do |transactions|
          transactions.first.timestamp == Time.utc(2010, 8, 19, 11, 43)
        end

        Transactor::ProcessJob.perform(
          [default_transaction_attributes.merge('timestamp' => timestamp)]
        )
      end
    end
  end
end
