module ThreeScale
  module Backend
    module Stats
      class KinesisAdapter
        # Each Kinesis record is rounded to the nearest 5KB to calculate the
        # cost. Each of our events is a hash with a few keys: service,
        # metric, period, time, value, etc. This means that the size of one
        # of our events is nowhere near 5KB. For that reason, we need to make
        # sure that we send many events in each record.
        # The max size for each record is 1000KB. In each record batch, Kinesis
        # accepts a maximum of 4MB.
        #
        # We will try to optimize the batching process later. For now, I will
        # just put 1000 events in each record. And batches of 5 records max.
        #
        # When we receive a number of events not big enough to fill a record,
        # those events are marked as pending events.
        # Kinesis can return errors, when that happens, the events of the
        # records that failed are re-enqueued as pending events.
        # The list of pending events is stored in Redis, so we do not fail to
        # process any events in case of downtime or errors.

        EVENTS_PER_RECORD = 1000
        private_constant :EVENTS_PER_RECORD

        MAX_RECORDS_PER_BATCH = 5
        private_constant :MAX_RECORDS_PER_BATCH

        EVENTS_PER_BATCH = EVENTS_PER_RECORD*MAX_RECORDS_PER_BATCH
        private_constant :EVENTS_PER_BATCH

        KINESIS_PENDING_EVENTS_KEY = 'send_to_kinesis:pending_events'
        private_constant :KINESIS_PENDING_EVENTS_KEY

        # We need to limit the number of pending events stored in Redis.
        # The Redis database can grow very quickly if a few consecutive jobs
        # fail. I am going to limit the number of pending events to 600k
        # (10 jobs approx.). If that limit is reached, we will disable the
        # creation of buckets in the system, but we will continue trying to
        # send the failed events. We will lose data, but that is better than
        # collapsing the whole Redis.
        # We will try to find a better alternative once we cannot afford to
        # miss events. Right now, we are just deleting the stats keys with
        # period = minute, so we can restore everything else.
        MAX_PENDING_EVENTS = 600_000
        private_constant :MAX_PENDING_EVENTS

        MAX_PENDING_EVENTS_REACHED_MSG =
            'Bucket creation has been disabled. Max pending events reached'.freeze
        private_constant :MAX_PENDING_EVENTS_REACHED_MSG

        def initialize(stream_name, kinesis_client, storage)
          @stream_name = stream_name
          @kinesis_client = kinesis_client
          @storage = storage
        end

        def send_events(events)
          pending_events = stored_pending_events + events

          if limit_pending_events_reached?(pending_events.size)
            Storage.disable!
            log_bucket_creation_disabled
          end

          # Batch events until we can fill at least one record
          if pending_events.size >= EVENTS_PER_RECORD
            failed_events = send_events_in_batches(pending_events)
            store_pending_events(failed_events)
          else
            store_pending_events(pending_events)
          end
        end

        # Sends the pending events to Kinesis, even if there are not enough of
        # them to fill 1 record.
        # Returns the number of events correctly sent to Kinesis
        def flush(limit = nil)
          pending_events = stored_pending_events
          events_to_flush = limit ? pending_events.take(limit) : pending_events
          failed_events = send_events_in_batches(events_to_flush)
          store_pending_events(pending_events - events_to_flush + failed_events)
          events_to_flush.size - failed_events.size
        end

        def num_pending_events
          storage.scard(KINESIS_PENDING_EVENTS_KEY)
        end

        private

        attr_reader :stream_name, :kinesis_client, :storage

        def stored_pending_events
          storage.smembers(KINESIS_PENDING_EVENTS_KEY).map do |pending_event|
            JSON.parse(pending_event, symbolize_names: true)
          end
        end

        def limit_pending_events_reached?(count)
          count > MAX_PENDING_EVENTS
        end

        def log_bucket_creation_disabled
          Backend.logger.info(MAX_PENDING_EVENTS_REACHED_MSG)
        end

        # Returns the failed events
        def send_events_in_batches(events)
          failed_events = []

          events.each_slice(EVENTS_PER_BATCH) do |events_slice|
            begin
              kinesis_resp = kinesis_client.put_record_batch(
                  { delivery_stream_name: stream_name,
                    records: events_to_kinesis_records(events_slice) })
              failed_events << failed_events_kinesis_resp(
                  kinesis_resp[:request_responses], events_slice)
            rescue Aws::Firehose::Errors::ServiceError
              failed_events << events_slice
            end
          end

          failed_events.flatten
        end

        def events_to_kinesis_records(events)
          # Record format expected by Kinesis:
          # [{ data: "data_event_group_1" }, { data: "data_event_group_2" }]
          events.each_slice(EVENTS_PER_RECORD).map do |events_slice|
            { data: events_to_pseudo_json(events_slice) }
          end
        end

        # We want to send to Kinesis events that can be read by Redshift.
        # Redshift expects events in JSON format without the '[]' and
        # without separating them with commas.
        # We put each event in a separated line, that will make their parsing
        # easier, but it is not needed by Redshift.
        def events_to_pseudo_json(events)
          events.map { |event| event.to_json }.join("\n") + "\n"
        end

        def failed_events_kinesis_resp(request_responses, events)
          failed_records_indexes = failed_records_indexes(request_responses)
          failed_records_indexes.flat_map do |failed_record_index|
            events_index_start = failed_record_index*EVENTS_PER_RECORD
            events_index_end = events_index_start + EVENTS_PER_RECORD - 1
            events[events_index_start..events_index_end]
          end
        end

        def failed_records_indexes(request_responses)
          result = []
          request_responses.each_with_index do |response, index|
            result << index unless response[:error_code].nil?
          end
          result
        end

        def store_pending_events(events)
          storage.pipelined do
            storage.del(KINESIS_PENDING_EVENTS_KEY)
            events.each do |event|
              storage.sadd(KINESIS_PENDING_EVENTS_KEY, event.to_json)
            end
          end
        end
      end
    end
  end
end
