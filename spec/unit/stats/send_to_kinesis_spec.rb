require_relative '../../spec_helper'
require_relative '../../../lib/3scale/backend/stats/send_to_kinesis'

module ThreeScale
  module Backend
    module Stats
      describe SendToKinesis do
        subject { SendToKinesis }

        before { expect(subject.enabled?).to be_false }

        describe '.enable' do
          it 'makes .enabled? return true' do
            subject.enable
            expect(subject.enabled?).to be_true
          end
        end

        describe '.disable' do
          before { subject.enable }

          it 'makes .enabled? return false' do
            subject.disable
            expect(subject.enabled?). to be_false
          end
        end
      end
    end
  end
end
