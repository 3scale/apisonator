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
        # We will also handle Kinesis errors later.

        EVENTS_PER_RECORD = 300
        private_constant :EVENTS_PER_RECORD

        MAX_RECORDS_PER_BATCH = 5
        private_constant :MAX_RECORDS_PER_BATCH

        def initialize(stream_name, kinesis_client)
          @stream_name = stream_name
          @kinesis_client = kinesis_client
          @pending_events = []
        end

        def send_events(events)
          self.pending_events += events

          # Batch events until we can fill at least one record
          if pending_events.size >= EVENTS_PER_RECORD
            events_to_send = pending_events.take(EVENTS_PER_RECORD*MAX_RECORDS_PER_BATCH)
            events_not_to_send = pending_events[EVENTS_PER_RECORD*MAX_RECORDS_PER_BATCH..-1] || []

            kinesis_client.put_record_batch(
                { delivery_stream_name: stream_name,
                  records: events_to_kinesis_records(events_to_send) })

            self.pending_events = events_not_to_send
          end
        end

        private

        attr_reader :stream_name, :kinesis_client
        attr_accessor :pending_events

        def events_to_kinesis_records(events)
          # Record format expected by Kinesis:
          # [{ data: "data_event_group_1" }, { data: "data_event_group_2" }]
          events.each_slice(EVENTS_PER_RECORD).map do |events_slice|
            { data: events_slice.to_json }
          end
        end
      end
    end
  end
end
