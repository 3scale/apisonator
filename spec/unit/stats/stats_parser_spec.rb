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
            context 'and with period = year' do
              let(:period) { 'year' }
              let(:time) { '20160101' }
              let(:key) do
                stats_key(service: service, cinstance: cinstance, metric: metric,
                          period: period, time: time)
              end

              it 'returns the correct hash' do
                expect(subject.parse(key, value))
                    .to eq({ service: service,
                             cinstance: cinstance,
                             metric: metric,
                             period: period,
                             timestamp: time + ' 00:00',
                             value: value })
              end
            end

            context 'and with period = month' do
              let(:period) { 'month' }
              let(:time) { '20160101' }
              let(:key) do
                stats_key(service: service, cinstance: cinstance, metric: metric,
                          period: period, time: time)
              end

              it 'returns the correct hash' do
                expect(subject.parse(key, value))
                    .to eq({ service: service,
                             cinstance: cinstance,
                             metric: metric,
                             period: period,
                             timestamp: time + ' 00:00',
                             value: value })
              end
            end

            context 'and with period = week' do
              let(:period) { 'week' }
              let(:time) { '20160101' }
              let(:key) do
                stats_key(service: service, cinstance: cinstance, metric: metric,
                          period: period, time: time)
              end

              it 'returns the correct hash' do
                expect(subject.parse(key, value))
                    .to eq({ service: service,
                             cinstance: cinstance,
                             metric: metric,
                             period: period,
                             timestamp: time + ' 00:00',
                             value: value })
              end
            end

            context 'and with period = day' do
              let(:key) do
                stats_key(service: service, cinstance: cinstance, metric: metric,
                          period: period, time: time)
              end

              it 'returns the correct hash' do
                expect(subject.parse(key, value))
                    .to eq({ service: service,
                             cinstance: cinstance,
                             metric: metric,
                             period: period,
                             timestamp: time + ' 00:00',
                             value: value })
              end
            end

            context 'and with period = hour' do
              let(:period) { 'hour' }
              let(:time) { '2016010411' }
              let(:key) do
                stats_key(service: service, cinstance: cinstance, metric: metric,
                          period: period, time: time)
              end

              it 'returns the correct hash' do
                expect(subject.parse(key, value))
                    .to eq({ service: service,
                             cinstance: cinstance,
                             metric: metric,
                             period: period,
                             timestamp: "#{time[0..7]} #{time[8..9]}:00",
                             value: value })
              end
            end

            context 'and with period = minute' do
              let(:period) { 'minute' }
              let(:time) { '201601041145' }
              let(:key) do
                stats_key(service: service, cinstance: cinstance, metric: metric,
                          period: period, time: time)
              end

              it 'returns the correct hash' do
                expect(subject.parse(key, value))
                    .to eq({ service: service,
                             cinstance: cinstance,
                             metric: metric,
                             period: period,
                             timestamp: "#{time[0..7]} #{time[8..9]}:#{time[10..11]}",
                             value: value })
              end
            end

            # The parse method might get 'compacted' times. This is performed
            # by ThreeScale::Backend::TimeHacks.to_compact_s
            # For example, for the period 'hour', we might get '20160101' when
            # hour = '00'
            context 'and with a time that has been "compacted"' do
              let(:period) { 'hour' }
              let(:time) { '20160101' }
              let(:key) do
                stats_key(service: service, cinstance: cinstance, metric: metric,
                          period: period, time: time)
              end

              it 'returns the correct hash' do
                expect(subject.parse(key, value))
                    .to eq({ service: service,
                             cinstance: cinstance,
                             metric: metric,
                             period: period,
                             timestamp: "#{time[0..7]} 00:00",
                             value: value })
              end
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
              stats_key(service: service, cinstance: cinstance, metric: metric,
                        period: period, time: time)
            end

            it 'raises StatsKeyValueInvalid' do
              expect { subject.parse(key, value) }
                  .to raise_error(StatsParser::StatsKeyValueInvalid)
            end
          end

          context 'with a key that contains N/A' do
            let(:key) do
              stats_key(service: service, uinstance: 'N/A', metric: metric,
                        period: period, time: time)
            end

            it 'returns the correct hash, setting the param with N/A to nil' do
              expect(subject.parse(key, value))
                  .to eq({ service: service,
                           uinstance: nil,
                           metric: metric,
                           period: period,
                           timestamp: time + ' 00:00',
                           value: value })
            end
          end

          context 'with a key that has period = eternity' do
            let(:key) do
              stats_key(service: service, cinstance: cinstance, metric: metric,
                        period: 'eternity')
            end

            it 'returns the correct hash' do
              expect(subject.parse(key, value))
                  .to eq({ service: service,
                           cinstance: cinstance,
                           metric: metric,
                           period: 'eternity',
                           timestamp: '',
                           value: value })
            end
          end
        end

        def stats_key(args)
          result = "stats/{service:#{args[:service]}"
          result << "/cinstance:#{args[:cinstance]}" if args[:cinstance]
          result << "/uinstance:#{args[:uinstance]}" if args[:uinstance]
          result << "/metric:#{args[:metric]}"

          result << if args['period'] == 'eternity'
                      '/eternity'
                    else
                      "/#{args[:period]}:#{args[:time]}"
                    end
        end
      end
    end
  end
end
