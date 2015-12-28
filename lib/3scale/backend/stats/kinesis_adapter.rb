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
        # just put 300 events in each record. And batches of 5 records max.
        #
        # When we receive a number of events not big enough to fill a record,
        # those events are marked as pending events.
        # Kinesis can return errors, when that happens, the events of the
        # records that failed are re-enqueued as pending events.
        # The list of pending events is stored in Redis, so we do not fail to
        # process any events in case of downtime or errors.

        EVENTS_PER_RECORD = 300
        private_constant :EVENTS_PER_RECORD

        MAX_RECORDS_PER_BATCH = 5
        private_constant :MAX_RECORDS_PER_BATCH

        KINESIS_PENDING_EVENTS_KEY = 'send_to_kinesis:pending_events'
        private_constant :KINESIS_PENDING_EVENTS_KEY

        def initialize(stream_name, kinesis_client, storage)
          @stream_name = stream_name
          @kinesis_client = kinesis_client
          @storage = storage
        end

        def send_events(events)
          pending_events = stored_pending_events + events

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
        def flush
          pending_events = stored_pending_events
          failed_events = send_events_in_batches(pending_events)
          store_pending_events(failed_events)
          pending_events.size - failed_events.size
        end

        private

        attr_reader :stream_name, :kinesis_client, :storage

        def stored_pending_events
          storage.smembers(KINESIS_PENDING_EVENTS_KEY).map do |pending_event|
            JSON.parse(pending_event, symbolize_names: true)
          end
        end

        # Returns the failed events
        def send_events_in_batches(events)
          failed_events = []
          events_per_batch = EVENTS_PER_RECORD*MAX_RECORDS_PER_BATCH

          events.each_slice(events_per_batch) do |events_slice|
            kinesis_resp = kinesis_client.put_record_batch(
                { delivery_stream_name: stream_name,
                  records: events_to_kinesis_records(events_slice) })
            failed_events << failed_events(kinesis_resp[:request_responses],
                                           events_slice)
          end

          failed_events.flatten
        end

        def events_to_kinesis_records(events)
          # Record format expected by Kinesis:
          # [{ data: "data_event_group_1" }, { data: "data_event_group_2" }]
          events.each_slice(EVENTS_PER_RECORD).map do |events_slice|
            { data: events_slice.to_json }
          end
        end

        def failed_events(request_responses, events)
          failed_records_indexes = failed_records_indexes(request_responses)
          failed_records_indexes.flat_map do |failed_record_index|
            events_index_start = failed_record_index*EVENTS_PER_RECORD
            events_index_end = events_index_start + EVENTS_PER_RECORD - 1
            events[events_index_start..events_index_end]
          end
        end

        def failed_records_indexes(request_responses)
          request_responses.each_index.reject do |index|
            request_responses[index][:error_code].nil?
          end
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
