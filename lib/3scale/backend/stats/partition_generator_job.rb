module ThreeScale
  module Backend
    module Stats
      class PartitionGeneratorJob < BackgroundJob
        # low priority queue
        @queue = :main

        class << self
          def perform_logged(_enqueue_time, service_id, applications, metrics, users, from, to, context_info = {})  end

          private

          def enqueue_time
            @args[0]
          end
        end
      end
    end
  end
end
