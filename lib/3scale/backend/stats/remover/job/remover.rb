module ThreeScale
  module Backend
    module Stats
      module Remover
        module Job
          class Remover < BackgroundJob
            @queue = :stats_remover

            DELETE_BATCH_SIZE = 50

            class << self
              include Logging

              def perform_logged(serialized_service_context, serialized_start_limit, serialized_end_limit, _enqueue_time)
                service_context = Serialize.parse_json(serialized_service_context)
                #service_context should be converted to
              end

              limits = [KeyIndex.parse_json(serialized_start_limit), KeyIndex.parse_json(serialized_end_limit)]

              stats_key_generator = Stats.get_key_type_key_generator(service_context, limits)

              stats_key_generator.each_slice(DELETE_BATCH_SIZE) do |keys_slice|
                ##Storage.del(keys_slice)
              end
            end
          end
        end
      end
    end
  end
end