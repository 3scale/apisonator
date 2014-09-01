require_relative '../spec_helper'
require_relative '../../lib/3scale/backend/storage_influxdb'

module ThreeScale
  module Backend
    describe StorageInfluxDB do
      def write_event(value)
        storage_influxdb.add_event(stats_key, value)
        storage_influxdb.write_events
      end

      def stats_key
        "stats/{service:%s}/metric:%s/day:%s" % [
          service_id,
          metric_id,
          time.to_compact_s,
        ]
      end

      before { storage_influxdb.drop_series }

      let(:storage_influxdb) { StorageInfluxDB.new('backend_test') }
      let(:time)             { Time.utc(2013, 7, 3) }
      let(:period)           { 'day' }
      let(:service_id)       { 1001 }
      let(:metric_id)        { 8001 }
      let(:value)            { 20 }
      let(:event_conditions) {
        {
            time:    time.to_i,
            metric:  metric_id,
        }
      }

      describe '#get' do
        let(:event_value) do
          storage_influxdb.get(service_id, period, event_conditions)
        end

        context "when it finds an event" do
          before { write_event(value) }

          it "returns event value" do
            expect(event_value).to be(value)
          end
        end

        context "when it doesnt find an event" do
          it "returns nil" do
            expect(event_value).to be_nil
          end
        end
      end

      describe "#find_event" do
        let(:event) do
          storage_influxdb.find_event(service_id, period, event_conditions)
        end

        context "when it finds an event" do
          before { write_event(value) }

          it "returns the event" do
            expect(event).to have_key("sequence_number")
            expect(event).to have_key("time")
            expect(event).to have_key("value")
          end
        end

        context "when it doesnt find an event" do
          it "returns nil" do
            expect(event).to be_nil
          end
        end
      end

      describe '#add_event' do
        let(:data)  { storage_influxdb.add_event(stats_key, value) }
        let(:event) { event_conditions.merge(value: value) }

        it "returns an array with data points" do
          expect(data).to eq([event])
        end
      end

      describe '#write_events' do
        context "without batched events to write" do
          it "returns true" do
            expect(storage_influxdb.write_events).to be_true
          end
        end

        context "with batched events to write" do
          it "returns true" do
            storage_influxdb.add_event(stats_key, value)
            expect(storage_influxdb.write_events).to be_true
          end
        end


        context "with new event point" do
          it "creates the point" do
            storage_influxdb.add_event(stats_key, value)
            storage_influxdb.write_events
            event = storage_influxdb.find_event(service_id, period, event_conditions)

            expect(event["value"]).to be(value)
            expect(event["sequence_number"]).not_to be_nil
          end
        end

        context "with existing event point" do
          before { write_event(value) }

          let(:new_value)      { 50 }
          let(:original_event) {
            storage_influxdb.find_event(service_id, period, event_conditions)
          }

          it "updates the point" do
            write_event(new_value)
            event = storage_influxdb.find_event(service_id, period, event_conditions)

            expect(event["sequence_number"]).to eq(original_event["sequence_number"])
            expect(event["value"]).to be(new_value)
          end
        end
      end

      describe '#drop_series' do
        before { write_event(value) }

        it "returns true" do
          expect(storage_influxdb.drop_series).to be_true
        end

        it "deletes event series" do
          expect(storage_influxdb.find_event(service_id, period, {})).not_to be_nil
          storage_influxdb.drop_series
          expect(storage_influxdb.find_event(service_id, period, {})).to be_nil
        end
      end
    end
  end
end
