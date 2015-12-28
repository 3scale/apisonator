require_relative 'send_to_kinesis_job'

module ThreeScale
  module Backend
    module Stats
      class SendToKinesis
        SEND_TO_KINESIS_ENABLED_KEY = 'send_to_kinesis:enabled'
        private_constant :SEND_TO_KINESIS_ENABLED_KEY

        class << self
          def enable
            storage.set(SEND_TO_KINESIS_ENABLED_KEY, '1')
          end

          def disable
            storage.del(SEND_TO_KINESIS_ENABLED_KEY)
          end

          def enabled?
            storage.get(SEND_TO_KINESIS_ENABLED_KEY).to_i == 1
          end

          def schedule_job
            if enabled?
              Resque.enqueue(SendToKinesisJob, Time.now.utc, Time.now.utc.to_f)
            end
          end

          private

          def storage
            Backend::Storage.instance
          end
        end
      end
    end
  end
end
