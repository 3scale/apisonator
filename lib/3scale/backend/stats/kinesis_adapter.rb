module ThreeScale
  module Backend
    module Stats
      class KinesisAdapter
        # Each Kinesis record is rounded to the nearest 5KB to calculate the
        # cost. Each of our events is a hash with a few keys: service,
        # metric, period, time, value, etc. This means that the size of one
        # of our events is nowhere near 5KB. For that reason, we need to make
        # sure that we send many events in each record.
        # The max size for each record is 1000KB.
        # We will try to optimize the batching process later.

        MAX_RECORD_SIZE_BYTES = 1000*1024
        private_constant :MAX_RECORD_SIZE_BYTES

        def initialize(stream_name, kinesis_client)
          @stream_name = stream_name
          @kinesis_client = kinesis_client
          @pending_events = []
        end

        def send_events(events)
          self.pending_events += events

          # Keep saving events unless we can fill one record at least
          if size_bytes(pending_events) >= MAX_RECORD_SIZE_BYTES
            kinesis_client.put_record_batch(
                { delivery_stream_name: stream_name,
                  records: events_to_kinesis_records(pending_events) })
            self.pending_events = []
          end
        end

        private

        attr_reader :stream_name, :kinesis_client
        attr_accessor :pending_events

        def events_to_kinesis_records(events)
          # Record format expected by Kinesis:
          # [{ data: "data_event_group_1" }, { data: "data_event_group_2" }]
          group_events(events).map do |events_group|
            { data: events_group.to_json }
          end
        end

        def group_events(events)
          result = []
          current_group = []

          events.each do |event|
            if size_bytes(current_group + [event]) < MAX_RECORD_SIZE_BYTES
              current_group << event
            else
              result << current_group
              current_group = [event]
            end
          end

          result << current_group
        end

        def size_bytes(events)
          events.to_json.bytesize
        end
      end
    end
  end
end
