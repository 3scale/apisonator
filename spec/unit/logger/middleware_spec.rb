module ThreeScale
  module Backend
    module Logging
      describe Middleware do
        def run_request
          if app.status == 500
            expect { rackrequest.run(subject) }.
              to raise_error(SpecHelpers::Rack::App::Error)
          else
            rackrequest.run(subject)
          end
        end

        let(:rackrequest) { SpecHelpers::Rack::Request.new }
        let(:time) { Time.now }

        let(:writers) do
          [double('writer1', log: '', log_error: ''),
           double('writer2', log: '', log_error: '')]
        end
        subject { described_class.new(app.app, writers: writers) }

        context 'when there are no errors' do
          let(:app) { SpecHelpers::Rack::App.new }

          it 'all the writers log the successful call' do
            writers.each do |writer|
              expect(writer)
                  .to receive(:log)
                  .with(rackrequest.env, app.status, {}, time)
                  .once
            end

            Timecop.freeze(time) { run_request }
          end
        end

        context 'when there is an error' do
          let(:app) { SpecHelpers::Rack::App.new(status: 500, failure: true) }

          it 'all the writers log the error' do
            writers.each do |writer|
              expect(writer)
                  .to receive(:log_error)
                  .with(rackrequest.env, app.status, app.exception.message, time)
                  .once
            end

            Timecop.freeze(time) { run_request }
          end
        end

        describe '.writers' do
          context 'with loggers' do
            let(:loggers) { described_class.const_get(:WRITERS).keys }
            let(:writer_classes) { described_class.const_get(:WRITERS).values }

            it 'returns the writers associated with the loggers' do
              writers = described_class.writers(loggers)
              expect(writer_classes.all? do |writer_class|
                writers.find { |writer| writer.is_a?(writer_class) }
              end).to be true
            end
          end

          context 'without loggers' do
            let(:default_writers) { described_class.const_get(:DEFAULT_WRITERS) }

            it 'returns the default writers' do
              [nil, []].each do |param|
                expect(described_class.writers(param)).to eq default_writers
              end
            end
          end

          context 'with an invalid logger' do
            let(:invalid_logger) { :invalid }
            invalid_logger_error = described_class::UnsupportedLoggerType

            it "raises #{invalid_logger_error}" do
              expect { described_class.writers([invalid_logger]) }
                  .to raise_error(invalid_logger_error)
            end
          end
        end
      end
    end
  end
end
