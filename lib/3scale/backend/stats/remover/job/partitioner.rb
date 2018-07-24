module ThreeScale
  module Backend
    module Stats
      module Remover
        module Job
          class Partitioner < BackgroundJob
            @queue = :stats_remover

            class << self
              include Logging

              def perform_logged(serialized_service_context, _enqueue_time)
                service_context = Serialize.parse_json(serialized_service_context)
                #service_context should be converted to
              end

              stats_key_generator = Stats.get_key_type_index_generator(service_context)

              partition_generator = Partition.new(stats_key_generator)
              partition_generator.each do |limit_start, limit_end|
                ::Resque.enqueue(limit_start, limit_end, Time.utc)
              end
            end
          end
        end
      end
    end
  end
end