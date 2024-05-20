module ThreeScale
  module Backend
    module Stats
      class Cleaner
        # Design notes:
        # Apisonator does not store in any Redis structure the stats keys
        # associated with a service. Doing so would imply:
        #   - Performance hit when reporting. After updating a stats key, it
        #   would need to be included in a set, which would increase the number
        #   of operations in Redis.
        #   - More space in Redis. To maintain the sets mentioned in the point
        #   above.
        #   - A data migration would be needed to create those sets from the
        #   existing stats keys.
        #
        # In order to avoid those costs, this class is implemented in a way that
        # does not need to keep an updated list of all the stats keys for every
        # service. Services marked for deletion are stored in a Redis set, and
        # then, a script, periodic cron, etc. is responsible for calling
        # delete!(). That method scans the whole database and deletes all the
        # stats keys that belong to those services marked to be deleted.
        # The downside of this method is that it requires direct access to the
        # redis servers. Going through a proxy like Twemproxy does not work,
        # because it does not support the "SCAN" command.
        #
        # In the past we tried an alternative approach. When we received a
        # request to delete the stats of a service, we generated all the
        # possible stats keys that could exist for it. That approach was not
        # efficient because it ended up generating many keys that didn't exist
        # and thus, unnecessary delete calls to Redis. That approach is also
        # more complex and error prone. You can find the details here:
        # https://github.com/3scale/apisonator/issues/90

        include Storable

        KEY_SERVICES_TO_DELETE = 'set_with_services_marked_for_deletion'.freeze
        private_constant :KEY_SERVICES_TO_DELETE

        SLEEP_BETWEEN_SCANS = 0.01 # In seconds
        private_constant :SLEEP_BETWEEN_SCANS

        SCAN_SLICE = 500
        private_constant :SCAN_SLICE

        STATS_KEY_PREFIX = 'stats/'.freeze
        private_constant :STATS_KEY_PREFIX

        REDIS_CONN_ERRORS = [Redis::BaseConnectionError, Errno::ECONNREFUSED, Errno::EPIPE].freeze
        private_constant :REDIS_CONN_ERRORS

        MAX_RETRIES_REDIS_ERRORS = 3
        private_constant :MAX_RETRIES_REDIS_ERRORS

        class << self
          include Logging
          def mark_service_to_be_deleted(service_id)
            storage.sadd(KEY_SERVICES_TO_DELETE, service_id)
          end

          # Deletes all the stats for the services that have been marked for
          # deletion.
          #
          # This method receives a collection of instantiated Redis clients.
          # Those clients need to connect to Redis servers directly. They cannot
          # connect to a proxy like Twemproxy. The reason is that this function
          # needs to scan the database using the "SCAN" command, which is not
          # supported by Twemproxy.
          #
          # The services marked as deletion will be marked as done only when
          # this function finishes deleting the keys from all the Redis servers.
          # This means that if the function raises in the middle of the
          # execution, those services will be retried in the next call.
          #
          # Note 1: keys deleted cannot be restored.
          # Note 2: this method can take a long time to finish as it needs to
          # scan all the keys in several DBs.
          #
          # @param [Array] redis_conns Instantiated Redis clients.
          # @param [IO] log_deleted_keys IO where to write the logs. Defaults to
          #             nil (logs nothing).
          def delete!(redis_conns, log_deleted_keys: nil)
            services = services_to_delete
            logger.info("Going to delete the stats keys for these services: #{services.to_a}")

            unless services.empty?
              _ok, failed = redis_conns.partition do |redis_conn|
                begin
                  delete_keys(redis_conn, services, log_deleted_keys)
                  true
                rescue => e
                  handle_redis_exception(e, redis_conn)
                  false
                end
              end

              with_retries { remove_services_from_delete_set(services) } if failed.empty?

              failed.each do |failed_conn|
                logger.error("Error while deleting stats of server #{failed_conn}")
              end
            end

            logger.info("Finished deleting the stats keys for these services: #{services.to_a}")
          end

          # Deletes all the stats keys set to 0.
          #
          # Stats keys set to 0 are useless and occupy Redis memory
          # unnecessarily. They were generated due to a bug in previous versions
          # of Apisonator.
          # Ref: https://github.com/3scale/apisonator/pull/247
          #
          # As the .delete function, this one also receives a collection of
          # instantiated Redis clients and those need to connect to Redis
          # servers directly.
          #
          # @param [Array] redis_conns Instantiated Redis clients.
          # @param [IO] log_deleted_keys IO where to write the logs. Defaults to
          #             nil (logs nothing).
          def delete_stats_keys_set_to_0(redis_conns, log_deleted_keys: nil)
            _ok, failed = redis_conns.partition do |redis_conn|
              begin
                delete_stats_keys_with_val_0(redis_conn, log_deleted_keys)
                true
              rescue => e
                handle_redis_exception(e, redis_conn)
                false
              end
            end

            failed.each do |failed_conn|
              logger.error("Error while deleting stats of server #{failed_conn}")
            end
          end

          private

          def handle_redis_exception(exception, redis_conn)
            # If it's a connection error, do nothing so we can continue with
            # other shards. If it's another kind of error, it could be caused by
            # a bug, so better re-raise.

            case exception
            when *REDIS_CONN_ERRORS
              # Do nothing.
            when Redis::CommandError
              raise exception if exception.message != 'ERR Connection timed out'.freeze
            else
              raise exception
            end
          end

          # Returns a set with the services included in the
          # SET_WITH_SERVICES_MARKED_FOR_DELETION Redis set.
          def services_to_delete
            res = []
            cursor = 0

            loop do
              cursor, services = storage.sscan(
                KEY_SERVICES_TO_DELETE, cursor, count: SCAN_SLICE
              )

              res += services

              break if cursor.to_i == 0

              sleep(SLEEP_BETWEEN_SCANS)
            end

            res.to_set
          end

          def delete_keys(redis_conn, services, log_deleted_keys)
            cursor = 0

            loop do
              with_retries do
                cursor, keys = redis_conn.scan(cursor, count: SCAN_SLICE)

                to_delete = keys.select { |key| delete_key?(key, services) }

                unless to_delete.empty?
                  if log_deleted_keys
                    values = redis_conn.mget(*(to_delete.to_a))
                    to_delete.each_with_index do |k, i|
                      log_deleted_keys.puts "#{k} #{values[i]}"
                    end
                  end

                  redis_conn.del(to_delete)
                end
              end

              break if cursor.to_i == 0

              sleep(SLEEP_BETWEEN_SCANS)
            end
          end

          def remove_services_from_delete_set(services)
            storage.pipelined do |pipeline|
              services.each do |service|
                pipeline.srem(KEY_SERVICES_TO_DELETE, service)
              end
            end
          end

          def delete_key?(key, services_to_delete)
            return false unless is_stats_key?(key)

            service_in_key = service_from_stats_key(key)
            service_in_key && services_to_delete.include?(service_in_key)
          end

          def is_stats_key?(key)
            # A key that starts with STATS_KEY_PREFIX is a stats key except if it
            # follows this pattern: /STATS_KEY_PREFIX{service:.*}\/cinstances/. That's a
            # type of key used only for the "first traffic" event
            # (ApplicationEvents.first_traffic).
            key.start_with?(STATS_KEY_PREFIX) && !key.match(/cinstances/)
          end

          # Returns nil when there's not a service encoded in the key or when
          # the stats key has an invalid format.
          def service_from_stats_key(stats_key)
            StatsParser.parse(stats_key, nil)[:service]
          rescue StatsParser::StatsKeyValueInvalid
            # This could happen with legacy stats keys. For example, a long time
            # ago some stats keys had a "city" and a "country" encoded, but
            # always empty. That format has not been used in a long time. We'll
            # simply ignore those keys.
            nil
          end

          def delete_stats_keys_with_val_0(redis_conn, log_deleted_keys)
            cursor = 0

            loop do
              with_retries do
                cursor, keys = redis_conn.scan(cursor, count: SCAN_SLICE)

                stats_keys = keys.select { |k| is_stats_key?(k) }

                unless stats_keys.empty?
                  values = redis_conn.mget(*stats_keys)
                  to_delete = stats_keys.zip(values).select { |_, v| v == '0'.freeze }.map(&:first)

                  unless to_delete.empty?
                    redis_conn.del(to_delete)
                    to_delete.each { |k| log_deleted_keys.puts k } if log_deleted_keys
                  end
                end
              end

              break if cursor.to_i == 0

              sleep(SLEEP_BETWEEN_SCANS)
            end
          end

          def with_retries(max = MAX_RETRIES_REDIS_ERRORS)
            retries = 0
            begin
              yield
            rescue Exception => e
              retries += 1
              retry if retries < max
              raise e
            end
          end
        end
      end
    end
  end
end
