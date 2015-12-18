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
            events_to_send = pending_events.take(EVENTS_PER_RECORD*MAX_RECORDS_PER_BATCH)
            events_not_to_send = pending_events[EVENTS_PER_RECORD*MAX_RECORDS_PER_BATCH..-1] || []

            kinesis_resp = kinesis_client.put_record_batch(
                { delivery_stream_name: stream_name,
                  records: events_to_kinesis_records(events_to_send) })

            pending_events = pending_events_after_request(
                kinesis_resp[:request_responses], events_to_send, events_not_to_send)
          end

          storage.pipelined do
            storage.del(KINESIS_PENDING_EVENTS_KEY)
            pending_events.each do |event|
              storage.sadd(KINESIS_PENDING_EVENTS_KEY, event.to_json)
            end
          end
        end

        private

        attr_reader :stream_name, :kinesis_client, :storage

        def stored_pending_events
          storage.smembers(KINESIS_PENDING_EVENTS_KEY).map do |pending_event|
            JSON.parse(pending_event, symbolize_names: true)
          end
        end

        def events_to_kinesis_records(events)
          # Record format expected by Kinesis:
          # [{ data: "data_event_group_1" }, { data: "data_event_group_2" }]
          events.each_slice(EVENTS_PER_RECORD).map do |events_slice|
            { data: events_slice.to_json }
          end
        end

        def pending_events_after_request(request_responses, events_to_send, events_not_to_send)
          failed_events(request_responses, events_to_send) + events_not_to_send
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
      end
    end
  end
end
