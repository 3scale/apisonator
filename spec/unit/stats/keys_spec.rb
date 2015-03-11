require_relative '../../spec_helper'

module ThreeScale
  module Backend
    module Stats
      describe Keys do
        let(:service_id)     { 1000 }
        let(:application_id) { 10 }
        let(:metric_id)      { 100 }
        let(:user_id)        { 20 }
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

        describe '.user_key_prefix' do
          let(:prefix) { "stats/{service:1000}"}
          let(:result) { Keys.user_key_prefix(prefix, user_id) }

          it 'returns a composed key with user id' do
            expect(result).to eq("stats/{service:1000}/uinstance:20")
          end
        end

        describe '.metric_key_prefix' do
          let(:prefix) { "stats/{service:1000}/cinstance:10"}
          let(:result) { Keys.metric_key_prefix(prefix, metric_id) }

          it 'returns a composed key with metric id' do
            expect(result).to eq("stats/{service:1000}/cinstance:10/metric:100")
          end
        end

        describe '.usage_value_key' do
          let(:app) {
            double("application", service_id: service_id, id: application_id)
          }

          context 'with eternity granularity' do
            let(:result) {
              Keys.usage_value_key(app, metric_id, :eternity, time)
            }

            it 'returns a composed key not including a timestamp' do
              expected = "stats/{service:1000}/cinstance:10/metric:100/eternity"
              expect(result).to eq(expected)
            end
          end

          context 'with hour granularity' do
            let(:result) {
              Keys.usage_value_key(app, metric_id, :hour, time)
            }

            it 'returns a composed key including a timestamp' do
              expected = "stats/{service:1000}/cinstance:10/metric:100/hour:2014072918"
              expect(result).to eq(expected)
            end
          end
        end

        describe '.user_usage_value_key' do
          let(:user) {
            double("user", service_id: service_id, username: user_id)
          }

          context 'with eternity granularity' do
            let(:result) {
              Keys.user_usage_value_key(user, metric_id, :eternity, time)
            }

            it 'returns a composed key not including a timestamp' do
              expected = "stats/{service:1000}/uinstance:20/metric:100/eternity"
              expect(result).to eq(expected)
            end
          end

          context 'with hour granularity' do
            let(:result) {
              Keys.user_usage_value_key(user, metric_id, :hour, time)
            }

            it 'returns a composed key including a timestamp' do
              expected = "stats/{service:1000}/uinstance:20/metric:100/hour:2014072918"
              expect(result).to eq(expected)
            end
          end
        end

        describe '.counter_key' do
          let(:prefix) { "stats/{service:1000}/cinstance:10/metric:100"}

          context 'with eternity granularity' do
            let(:result) { Keys.counter_key(prefix, :eternity, time)}

            it 'returns a composed key not including a timestamp' do
              expected = "stats/{service:1000}/cinstance:10/metric:100/eternity"
              expect(result).to eq(expected)
            end
          end

          context 'with hour granularity' do
            let(:result) { Keys.counter_key(prefix, :hour, time)}

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
