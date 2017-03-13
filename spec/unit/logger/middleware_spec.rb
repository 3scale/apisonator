module ThreeScale
  module Backend
    class Logger
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
      end
    end
  end
end
