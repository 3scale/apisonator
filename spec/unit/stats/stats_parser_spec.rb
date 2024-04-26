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

          shared_examples 'key with all required params' do |period, time|
            let(:key) do
              stats_key(service: service, cinstance: cinstance, metric: metric,
                        period: period, time: time)
            end

            let(:expected_timestamp) do
              if %w(year month week day).include? period
                time + ' 00:00'
              elsif period == 'hour'
                "#{time[0..7]} #{time[8..9]}:00"
              elsif period == 'minute'
                "#{time[0..7]} #{time[8..9]}:#{time[10..11]}"
              end
            end

            it 'returns the correct hash' do
              expect(subject.parse(key, value))
                  .to eq({ service: service,
                           cinstance: cinstance,
                           metric: metric,
                           period: period,
                           timestamp: expected_timestamp,
                           value: value })
            end
          end

          context 'with a key that contains all the required params' do
            { year: '20160101',
              month: '20160101',
              week: '20160101',
              day: '20160101',
              hour: '2016010411',
              minute: '201601041145'
            }.each do |period, time|
              context "and with period = #{period}" do
                include_examples 'key with all required params', period.to_s, time
              end
            end

            # The parse method might get 'compacted' times. This is performed
            # by ThreeScale::Backend::TimeHacks.to_compact_s
            # For example, for the period 'hour', we might get '20160101' when
            # hour = '00'. When period is 'hour' we might get '201601011' when
            # hour = '10'. Yes, I hope we can get rid of that compact function
            # some day...
            context 'and with a time that has been "compacted"' do
              context 'without hours or minutes but granularity hour' do
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

              context 'with granularity hour and compacted hour (1 represents 10)' do
                let(:period) { 'hour' }
                let(:time) { '201601011' }
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
                               timestamp: "#{time[0..7]} 10:00",
                               value: value })
                end
              end

              context 'with granularity minute and 1 digit minute' do
                let(:period) { 'minute' }
                let(:time) { '20160101103' }
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
                               timestamp: "#{time[0..7]} 10:30",
                               value: value })
                end
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
