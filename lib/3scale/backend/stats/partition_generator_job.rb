module ThreeScale
  module Backend
    module Stats
      # Job for deleting service stats
      # Maps delete job definition to a set of non overlapping key set partitions
      class PartitionGeneratorJob < BackgroundJob
        # low priority queue
        @queue = :stats

        class << self
          include Configurable

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

            stats_key_gen = KeyGenerator.new(job.to_hash)

            # Generate partitions
            0.step(stats_key_gen.keys.count, configuration.stats.delete_partition_batch_size).each do |idx|
              Resque.enqueue(PartitionEraserJob, Time.now.getutc.to_f, service_id, applications,
                             metrics, users, from, to, idx,
                             configuration.stats.delete_partition_batch_size, context_info)
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
