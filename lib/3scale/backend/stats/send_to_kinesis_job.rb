require 'aws-sdk'
require '3scale/backend/stats/kinesis_adapter'
require '3scale/backend/stats/stats_parser'

module ThreeScale
  module Backend
    module Stats

      # This job works as follows:
      #   1) Reads the pending events from the buckets that have not been read.
      #   2) Parses and filters those events.
      #   3) Sends the events to the Kinesis adapter.
      #   4) Updates the latest bucket read, to avoid processing buckets more
      #      than once.
      # The events are sent in batches to Kinesis, but the component that does
      # that batching is the Kinesis adapter.
      #
      # Before sending the events to Kinesis, we attach a 'time_gen' attribute
      # to each of them. This is a timestamp that indicates approximately when
      # the event was generated based on the bucket where it was stored.
      # We need this attribute because we will have repeated event keys in
      # Redis and we will need to know which one contains the most updated
      # value.
      # Notice that we do not send all the events that are in the buckets to
      # Kinesis. This job reads several buckets each time it runs. Some events
      # can be repeated across those buckets. However, the job will only send
      # to Kinesis the latest value (the one in the most recent bucket). This
      # reduces the information that we need to parse, filter, and send.
      # We need the extra field 'time_gen', because we cannot safely assume any
      # order in S3 when sending events to Kinesis.
      class SendToKinesisJob < BackgroundJob
        @queue = :stats

        FILTERED_EVENT_PERIODS = %w(week eternity)
        private_constant :FILTERED_EVENT_PERIODS

        # We need to limit the amount of buckets that a job can process.
        # Otherwise, there is the possibility that the job would not finish
        # before its expiration time, and the next one would start processing
        # the same buckets.
        MAX_BUCKETS = 60
        private_constant :MAX_BUCKETS

        FILTERED_EVENT_PERIODS_STR = FILTERED_EVENT_PERIODS.map do |period|
          "/#{period}".freeze
        end.freeze
        private_constant :FILTERED_EVENT_PERIODS_STR

        class << self
          include Backend::Logging

          def perform_logged(end_time_utc, lock_key, _enqueue_time)
            # end_time_utc will be a string when the worker processes this job.
            # The parameter is passed through Redis as a string. We need to
            # convert it back.
            events_sent = 0

            end_time = DateTime.parse(end_time_utc).to_time.utc
            pending_events = bucket_reader.pending_events_in_buckets(
                end_time_utc: end_time, max_buckets: MAX_BUCKETS)

            unless pending_events[:events].empty?
              events = prepare_events(pending_events[:latest_bucket],
                                      pending_events[:events])
              kinesis_adapter.send_events(events)
              bucket_reader.latest_bucket_read = pending_events[:latest_bucket]
              events_sent = events.size

              # We might use a different strategy to delete buckets in the
              # future, but for now, we are going to delete the buckets as they
              # are read
              bucket_storage.delete_range(pending_events[:latest_bucket])
            end

            SendToKinesis.job_finished(lock_key)
            [true, msg_events_sent(events_sent)]
          end

          private

          def prepare_events(bucket, events)
            filter_events(events)
            parsed_events = parse_events(events.lazy)
            add_time_gen_to_events(parsed_events, bucket_to_timestamp(bucket)).force
          end

          # Parses the events and discards the invalid ones
          def parse_events(events)
            events.map do |k, v|
              begin
                StatsParser.parse(k, v)
              rescue StatsParser::StatsKeyValueInvalid
                logger.notify("Invalid stats key-value. k: #{k}. v: #{v}")
                nil
              end
            end.reject(&:nil?)
          end

          # We do not want to send all the events to Kinesis.
          # This method filters them.
          def filter_events(events)
            events.reject! do |event|
              FILTERED_EVENT_PERIODS_STR.any? do |filtered_period|
                event.include?(filtered_period)
              end
            end
          end

          def add_time_gen_to_events(events, time_gen)
            events.map { |event| event[:time_gen] = time_gen; event }
          end

          def bucket_to_timestamp(bucket)
            DateTime.parse(bucket).to_time.utc.strftime('%Y%m%d %H:%M:%S')
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
            Stats::Storage.bucket_storage
          end

          def bucket_reader
            Stats::Storage.bucket_reader
          end

          def kinesis_client
            Aws::Firehose::Client.new(
                region: config.kinesis_region,
                access_key_id: config.aws_access_key_id,
                secret_access_key: config.aws_secret_access_key)
          end

          def kinesis_adapter
            KinesisAdapter.new(config.kinesis_stream_name, kinesis_client, storage)
          end
        end
      end
    end
    
  end
end
