require 'aws-sdk'
require_relative 'send_to_kinesis_job'
require_relative 'kinesis_adapter'

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

          def flush_pending_events
            kinesis_adapter.flush if enabled?
          end

          private

          def storage
            Backend::Storage.instance
          end

          def kinesis_adapter
            kinesis_client = Aws::Firehose::Client.new(
                region: config.kinesis_region,
                access_key_id: config.aws_access_key_id,
                secret_access_key: config.aws_secret_access_key)
            KinesisAdapter.new(config.kinesis_stream_name, kinesis_client, storage)
          end
        end
      end
    end
  end
end
