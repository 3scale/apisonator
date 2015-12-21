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

        class << self
          def perform_logged(end_time_utc)
            # end_time_utc will be a string when the worker processes this job.
            # The parameter is passed through Redis as a string. We need to
            # convert it back.
            end_time = DateTime.parse(end_time_utc).to_time.utc

            pending_events = bucket_reader.pending_events_in_buckets(end_time)

            unless pending_events[:events].empty?
              parsed_events = pending_events[:events].map do |k, v|
                StatsParser.parse(k, v)
              end

              kinesis_adapter.send_events(parsed_events)
              bucket_reader.latest_bucket_read = pending_events[:latest_bucket]
            end

            [true, msg_events_sent(pending_events[:events].size)]
          end

          private

          def msg_events_sent(n_events)
            "#{n_events} events have been sent to the Kinesis adapter"
          end

          def storage
            Backend::Storage.instance
          end

          def config
            Backend.configuration
          end

          def bucket_reader
            BucketReader.new(config.stats.bucket_size, BucketStorage.new(storage), storage)
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
