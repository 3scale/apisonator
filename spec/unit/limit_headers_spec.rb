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
              double(period: Period::Month.new(Time.now.utc),
                     remaining_same_calls: 10,
                     remaining_time: 100)
            end

            it 'returns the remaining and the reset time for that report' do
              result = subject.get([report])

              expected = { remaining: report.remaining_same_calls,
                           reset: report.remaining_time }
              expect(result).to eq expected
            end
          end

          context 'when several reports are received' do
            context 'and their remaining usage is the same' do
              let(:time) { Time.now.utc }

              let(:report_month) do
                double(period: Period::Month.new(time),
                       remaining_same_calls: 10,
                       remaining_time: 100)
              end

              let(:report_year) do
                double(period: Period::Year.new(time),
                       remaining_same_calls: 10,
                       remaining_time: 200)
              end

              it 'returns the remaining and reset time of the report with the'\
                 'longest period' do
                result = subject.get([report_month, report_year])

                expected = { remaining: report_year.remaining_same_calls,
                             reset: report_year.remaining_time }
                expect(result).to eq expected
              end
            end

            context 'and their remaining usage is different' do
              let(:time) { Time.now.utc }

              let(:report_more_remaining) do
                double(period: Period::Month.new(time),
                       remaining_same_calls: 10,
                       remaining_time: 100)
              end

              let(:report_less_remaining) do
                double(period: Period::Month.new(time),
                       remaining_same_calls: report_more_remaining.remaining_same_calls - 1,
                       remaining_time: 200)
              end

              it 'returns the remaining and reset time of the report with the'\
                 'smallest remaining' do
                result = subject.get([report_more_remaining,
                                      report_less_remaining])

                expected = { remaining: report_less_remaining.remaining_same_calls,
                             reset: report_less_remaining.remaining_time }
                expect(result).to eq expected
              end
            end
          end
        end
      end
    end
  end
end
