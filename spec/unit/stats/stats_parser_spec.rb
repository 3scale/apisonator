require_relative '../../spec_helper'
require_relative '../../../lib/3scale/backend/stats/stats_parser'

module ThreeScale
  module Backend
    module Stats
      describe ThreeScale::Backend::Stats::StatsParser do
        describe '.parse' do
          let(:service) { '19' }
          let(:cinstance) { '85fb' }
          let(:uinstance) { '86fb' }
          let(:metric) { '299' }
          let(:period) { 'day' }
          let(:time) { '20151202' }
          let(:value) { '10' }

          subject { StatsParser }

          context 'with a key that contains all the required params' do
            let(:key) do
              "stats/{service:#{service}}/cinstance:#{cinstance}/metric:#{metric}/#{period}:#{time}"
            end

            it 'returns the correct hash' do
              expect(subject.parse(key, value))
                  .to eq({ service: service,
                           cinstance: cinstance,
                           metric: metric,
                           period: period,
                           year: time[0..3],
                           month: time[4..5],
                           day: time[6..7],
                           hour: nil,
                           minute: nil,
                           value: value })
            end
          end

          context 'with a key that does not contain all the required params' do
            let(:key) do
              "stats/{service:#{service}}"
            end

            it 'raises StatsKeyValueInvalid' do
              expect { subject.parse(key, value) }
                  .to raise_error(StatsParser::StatsKeyValueInvalid)
            end
          end

          context 'with a key that contains non-expected params' do
            let(:key) { 'stats/non_expected_param:3' }

            it 'raises StatsKeyValueInvalid' do
              expect { subject.parse(key, value) }
                  .to raise_error(StatsParser::StatsKeyValueInvalid)
            end
          end

          context 'with a key that contains an invalid period' do
            let(:period) { 'invalid_period' }
            let(:key) do
              "stats/{service:#{service}}/cinstance:#{cinstance}/metric:#{metric}/#{period}:#{time}"
            end

            it 'raises StatsKeyValueInvalid' do
              expect { subject.parse(key, value) }
                  .to raise_error(StatsParser::StatsKeyValueInvalid)
            end
          end

          context 'with a key that contains N/A' do
            let(:key) do
              "stats/{service:#{service}}/uinstance:N/A/metric:#{metric}/#{period}:#{time}"
            end

            it 'returns the correct hash, setting the param with N/A to nil' do
              expect(subject.parse(key, value))
                  .to eq({ service: service,
                           uinstance: nil,
                           metric: metric,
                           period: period,
                           year: time[0..3],
                           month: time[4..5],
                           day: time[6..7],
                           hour: nil,
                           minute: nil,
                           value: value })
            end
          end

          context 'with a key that has period = eternity' do
            let(:key) do
              "stats/{service:#{service}}/cinstance:#{cinstance}/metric:#{metric}/eternity"
            end

            it 'returns the correct hash' do
              expect(subject.parse(key, value))
                  .to eq({ service: service,
                           cinstance: cinstance,
                           metric: metric,
                           period: 'eternity',
                           year: nil,
                           month: nil,
                           day: nil,
                           hour: nil,
                           minute: nil,
                           value: value })
            end
          end
        end
      end
    end
  end
end
