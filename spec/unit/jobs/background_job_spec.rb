require_relative '../../spec_helper'

module ThreeScale
  module Backend
    describe BackgroundJob do
      class FooJob < BackgroundJob

        def self.perform_logged(*args)
          sleep 0.15
          [true, 'job was successful']
        end
      end

      class BarJob < BackgroundJob
        def self.perform_logged(*args); end
      end

      describe 'logging a proper Job' do
        before do
          allow(Worker).to receive(:logger).and_return(
            ::Logger.new(@log = StringIO.new))
          FooJob.perform(Time.now.getutc.to_f)
          @log.rewind
        end

        it 'logs class name' do
          expect(@log.read).to match /FooJob/
        end

        it 'logs job message' do
          expect(@log.read).to match /job was successful/
        end

        it 'logs execution time' do
          expect(@log.read).to match /0\.15/
        end
      end

      describe 'invalid Job' do
        before { ThreeScale::Backend::Worker.new }

        it 'complains when you don\'t set a log message' do
          expect { BarJob.perform() }.to raise_error(
            BackgroundJob::Error, 'No job message given')
        end
      end
    end
  end
end

