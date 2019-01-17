module ThreeScale
  module Backend
    module Stats
      # TODO: from configuration
      DELETE_BATCH_SIZE = 50
      # Job for deleting service stats
      # Perform actual key deletion from a key partition definition
      class PartitionEraserJob < BackgroundJob
        # low priority queue
        @queue = :main

        class << self
          include StorageHelpers

          def perform_logged(_enqueue_time, service_id, applications, metrics, users,
                             from, to, offset, length, context_info = {})
            job = DeleteJobDef.new(
              service_id: service_id,
              applications: applications,
              metrics: metrics,
              users: users,
              from: from,
              to: to
            )

            validate_job(job, offset, length)

            stats_key_types = KeyTypesFactory.create(job)

            stats_key_gen = KeyGenerator.new(stats_key_types)

            stats_key_gen.keys.drop(offset).take(length).each_slice(DELETE_BATCH_SIZE) do |slice|
              storage.del(slice)
            end

            [true, { job: job.to_hash, offset: offset, lenght: length }.to_json]
          rescue Error => error
            ErrorStorage.store(service_id, error, context_info)
            [false, "#{service_id} #{error}"]
          rescue Exception => error
            if error.class == ArgumentError && error.message == 'invalid byte sequence in UTF-8'
              ErrorStorage.store(service_id, NotValidData.new, context_info)
              [false, "#{service_id} #{error}"]
            else
              raise error
            end
          end

          private

          def validate_job(job, offset, length)
            job.validate

            unless offset.is_a? Integer
              raise DeleteServiceStatsValidationError.new(job.service_id, 'offset field value ' \
                                                          "[#{offset}] validation error")
            end

            unless length.is_a? Integer
              raise DeleteServiceStatsValidationError.new(job.service_id, 'length field value ' \
                                                          "[#{length}] validation error")
            end
          end

          def enqueue_time
            @args[0]
          end
        end
      end
    end
  end
end
