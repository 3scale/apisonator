module ThreeScale
  module Backend
    module Stats
      # Job for deleting service stats
      # Maps delete job definition to a set of non overlapping key set partitions
      class PartitionGeneratorJob < BackgroundJob
        # low priority queue
        @queue = :stats

        class << self
          def perform_logged(_enqueue_time, service_id, applications, metrics, users,
                             from, to, context_info = {})
            job = DeleteJobDef.new(
              service_id: service_id,
              applications: applications,
              metrics: metrics,
              users: users,
              from: from,
              to: to
            )

            stats_key_types = KeyTypesFactory.create(job)

            stats_key_gen = KeyGenerator.new(stats_key_types)

            partition_generator = PartitionGenerator.new(stats_key_gen)

            partition_generator.partitions(PARTITION_BATCH_SIZE).each do |idx|
              Resque.enqueue(PartitionEraserJob, Time.now.getutc.to_f, service_id, applications,
                             metrics, users, from, to, idx, PARTITION_BATCH_SIZE, context_info)
            end

            [true, job.to_json]
          rescue Backend::Error => error
            [false, "#{service_id} #{error}"]
          end

          private

          def enqueue_time
            @args[0]
          end
        end
      end
    end
  end
end
