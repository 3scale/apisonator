
module ThreeScale
  module Backend
    module Stats
      describe Keys do
        def self.currify(m, *args)
          Keys.method(m).curry.call(*args)
        end
        private_class_method :currify

        Application = Struct.new(:service_id, :id)
        app = Application.new 1000, 10

        let(:app)            { app }
        let(:service_id)     { app.service_id }
        let(:application_id) { app.id }
        let(:metric_id)      { 100 }
        let(:time)           { Time.utc(2014, 7, 29, 18, 25) }

        describe '.service_key_prefix' do
          let(:result)  { Keys.service_key_prefix(service_id) }
          it 'returns a composed key' do
            expect(result).to eq("stats/{service:1000}")
          end
        end

        describe '.application_key_prefix' do
          let(:prefix) { "stats/{service:1000}"}
          let(:result) {
            Keys.application_key_prefix(prefix, application_id)
          }

          it 'returns a composed key with application id' do
            expect(result).to eq("stats/{service:1000}/cinstance:10")
          end
        end

        describe '.metric_key_prefix' do
          let(:prefix) { "stats/{service:1000}/cinstance:10"}
          let(:result) { Keys.metric_key_prefix(prefix, metric_id) }

          it 'returns a composed key with metric id' do
            expect(result).to eq("stats/{service:1000}/cinstance:10/metric:100")
          end
        end

        describe '.response_code_key_prefix' do
          let(:prefix) { "stats/{service:1000}/cinstance:10"}
          let(:result) { Keys.response_code_key_prefix(prefix, 404) }

          it 'returns a composed key with metric id' do
            expect(result).to eq("stats/{service:1000}/cinstance:10/response_code:404")
          end
        end

        shared_examples_for 'usage keys' do |method, expected_key_part|
          context 'with eternity granularity' do
            let(:result) {
              method.call(metric_id, Period[:eternity, time])
            }

            it 'returns a composed key not including a timestamp' do
              expected = "stats/{service:1000}/#{expected_key_part}/metric:#{metric_id}/eternity"
              expect(result).to eq(expected)
            end
          end

          context 'with hour granularity' do
            let(:result) {
              method.call(metric_id, Period[:hour, time])
            }

            it 'returns a composed key including a timestamp' do
              expected = "stats/{service:1000}/#{expected_key_part}/metric:#{metric_id}/hour:2014072918"
              expect(result).to eq(expected)
            end
          end
        end

        describe '.application_usage_value_key' do
          it_behaves_like 'usage keys', currify(:application_usage_value_key, app.service_id, app.id), "cinstance:#{app.id}"
        end

        describe '.counter_key' do
          let(:prefix) { "stats/{service:1000}/cinstance:10/metric:100"}

          context 'with eternity granularity' do
            let(:result) { Keys.counter_key(prefix, Period[:eternity, time])}

            it 'returns a composed key not including a timestamp' do
              expected = "stats/{service:1000}/cinstance:10/metric:100/eternity"
              expect(result).to eq(expected)
            end
          end

          context 'with hour granularity' do
            let(:result) { Keys.counter_key(prefix, Period[:hour, time])}

            it 'returns a composed key including a timestamp' do
              expected = "stats/{service:1000}/cinstance:10/metric:100/hour:2014072918"
              expect(result).to eq(expected)
            end
          end
        end
      end
    end
  end
end
