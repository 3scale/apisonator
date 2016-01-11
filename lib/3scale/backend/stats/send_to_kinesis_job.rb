require 'aws-sdk'
require '3scale/backend/stats/bucket_reader'
require '3scale/backend/stats/bucket_storage'
require '3scale/backend/stats/kinesis_adapter'
require '3scale/backend/stats/stats_parser'

module ThreeScale
  module Backend
    module Stats

      # This job works as follows:
      #   1) Reads the pending events from the buckets that have not been read.
      #   2) Parses those events.
      #   3) Sends the parsed events to the Kinesis adapter.
      #   4) Updates the latest bucket read, to avoid processing buckets more
      #      than once.
      # The events are sent in batches to Kinesis, but the component that does
      # that batching is the Kinesis adapter.
      class SendToKinesisJob < BackgroundJob
        @queue = :stats

        FILTERED_EVENT_PERIODS = %w(week eternity)
        private_constant :FILTERED_EVENT_PERIODS

        class << self
          def perform_logged(end_time_utc, lock_key, _)
            # end_time_utc will be a string when the worker processes this job.
            # The parameter is passed through Redis as a string. We need to
            # convert it back.
            end_time = DateTime.parse(end_time_utc).to_time.utc

            events_sent = 0
            pending_events = bucket_reader.pending_events_in_buckets(end_time)

            unless pending_events[:events].empty?
              parsed_events = parse_events(pending_events[:events])
              filtered_events = filter_events(parsed_events)
              kinesis_adapter.send_events(filtered_events)
              bucket_reader.latest_bucket_read = pending_events[:latest_bucket]

              events_sent = filtered_events.size

              # We might use a different strategy to delete buckets in the
              # future, but for now, we are going to delete the buckets as they
              # are read
              bucket_storage.delete_range(pending_events[:latest_bucket])
            end

            SendToKinesis.job_finished(lock_key)
            [true, msg_events_sent(events_sent)]
          end

          private

          def parse_events(events)
            events.map { |k, v| StatsParser.parse(k, v) }
          end

          # We do not want to send all the events to Kinesis.
          # This method filters them.
          def filter_events(events)
            events.reject do |event|
              FILTERED_EVENT_PERIODS.include?(event[:period])
            end
          end

          def msg_events_sent(n_events)
            "#{n_events} events have been sent to the Kinesis adapter"
          end

          def storage
            Backend::Storage.instance
          end

          def config
            Backend.configuration
          end

          def bucket_storage
            BucketStorage.new(storage)
          end

          def bucket_reader
            BucketReader.new(config.stats.bucket_size, bucket_storage, storage)
          end

          def kinesis_adapter
            kinesis_client = Aws::Firehose::Client.new(
                region: config.kinesis_region,
                access_key_id: config.aws_access_key_id,
                secret_access_key: config.aws_secret_access_key)
            KinesisAdapter.new(config.kinesis_stream_name, kinesis_client, storage)
          end
        end
      end
    end
    
  end
end
