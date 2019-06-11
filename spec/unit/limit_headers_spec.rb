module ThreeScale
  module Backend
    module Transactor
      describe LimitHeaders do
        describe '.get' do
          subject { described_class }

          context 'when no reports are received' do
            it 'returns headers without constraints' do
              expect(subject.get([])).to eq({ remaining: -1, reset: -1 })
            end
          end

          context 'when only one report is received' do
            let(:report) do
              object_double(Status::UsageReport.allocate,
                            period: Period::Month.new(Time.now.utc),
                            remaining_same_calls: 10,
                            remaining_time: 100,
                            max_value: 200)
            end

            it 'returns the remaining, the reset time, and the max value for that report' do
              result = subject.get([report])

              expected = { remaining: report.remaining_same_calls,
                           reset: report.remaining_time,
                           'max-value': report.max_value }
              expect(result).to eq expected
            end
          end

          context 'when several reports are received' do
            context 'and their remaining usage is the same' do
              let(:time) { Time.now.utc }

              let(:report_month) do
                object_double(Status::UsageReport.allocate,
                              period: Period::Month.new(time),
                              remaining_same_calls: 10,
                              remaining_time: 100,
                              max_value: 50)
              end

              let(:report_year) do
                object_double(Status::UsageReport.allocate,
                              period: Period::Year.new(time),
                              remaining_same_calls: 10,
                              remaining_time: 200,
                              max_value: 100)
              end

              it 'returns the remaining, the reset time, and the max value '\
                 'of the report with the longest period' do
                result = subject.get([report_month, report_year])

                expected = { remaining: report_year.remaining_same_calls,
                             reset: report_year.remaining_time,
                             'max-value': report_year.max_value }
                expect(result).to eq expected
              end
            end

            context 'and their remaining usage is different' do
              let(:time) { Time.now.utc }

              let(:report_more_remaining) do
                object_double(Status::UsageReport.allocate,
                              period: Period::Month.new(time),
                              remaining_same_calls: 10,
                              remaining_time: 100,
                              max_value: 200)
              end

              let(:report_less_remaining) do
                object_double(Status::UsageReport.allocate,
                              period: Period::Month.new(time),
                              remaining_same_calls: report_more_remaining.remaining_same_calls - 1,
                              remaining_time: 200,
                              max_value: 300)
              end

              it 'returns the remaining, the reset time, and the max value '\
                 'of the report with the smallest remaining' do
                result = subject.get([report_more_remaining,
                                      report_less_remaining])

                expected = { remaining: report_less_remaining.remaining_same_calls,
                             reset: report_less_remaining.remaining_time,
                             'max-value': report_less_remaining.max_value }
                expect(result).to eq expected
              end
            end

            context 'and one of them has a remaining of 0' do
              let(:time) { Time.now.utc }

              let(:report_with_some_remaining) do
                object_double(Status::UsageReport.allocate,
                              period: Period::Day.new(time),
                              remaining_same_calls: 100,
                              remaining_time: 65,
                              max_value: 100)
              end

              let(:report_with_0_remaining) do
                object_double(Status::UsageReport.allocate,
                              period: Period::Hour.new(time),
                              remaining_same_calls: 0,
                              remaining_time: 5,
                              max_value: 200)
              end

              it 'returns a remaining of 0, the reset time, and the max '\
                 'value of the report with 0 remaining' do
                result = subject.get([report_with_some_remaining,
                                      report_with_0_remaining])

                expect(result).to eq(
                  { remaining: 0,
                    reset: report_with_0_remaining.remaining_time,
                    'max-value': report_with_0_remaining.max_value })
              end
            end
          end
        end
      end
    end
  end
end
