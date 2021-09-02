require 'pg'

module ThreeScale
  module Backend
    module Analytics
      module Redshift
        # This class imports the events stored by Kinesis in S3 into Redshift.
        # It keeps track of the events that have been imported so it does not
        # read twice the same S3 path.
        #
        # We store 'repeated' events in S3. This means that we can find several
        # times the same {service, instance, uinstance, metric, period, timestamp}
        # combination.
        #
        # In order to avoid storing repeated information in Redshift we need to
        # perform UPSERTs. The algorithm followed is the one explained in the
        # official Redshift documentation:
        # http://docs.aws.amazon.com/redshift/latest/dg/t_updating-inserting-using-staging-tables-.html
        # The process is as follows:
        #  1) Create a temporary table with the data imported from S3, including
        #     duplicates.
        #     Two attributes can have nulls: cinstance and uinstance. We replace
        #     those nulls with ''. I have observed substantial performance gains
        #     because of this.
        #  2) Perform the necessary operations in the temp table to remove
        #     duplicates. (In our case this basically consists of an inner-join).
        #  3) Inside a transaction, delete all the events that are in the temp
        #     table from the final table. Next, insert the ones in the temp
        #     table into the final table. Finally, remove the temp table.
        #  4) Last, we perform a vacuum, because Redshift does not automatically
        #     reclaim and reuse space that has been freed after deletes or
        #     updates. The vacuum operation also leaves the table sorted.
        #     More info:
        #     http://docs.aws.amazon.com/redshift/latest/dg/t_Reclaiming_storage_space202.html
        #     Right now, we are going to vacuum every time we insert new data,
        #     we will see if for performance reasons we need to do it less often.
        class Adapter

          module SQL
            SCHEMA = 'backend'.freeze

            # This importer relies on some tables or views that are created in
            # Redshift to function correctly.
            TABLES = { events: "#{SCHEMA}.events".freeze,
                       latest_s3_path_read: "#{SCHEMA}.latest_s3_path_read".freeze,
                       temp: "#{SCHEMA}.temp_events".freeze,
                       unique_imported_events: "#{SCHEMA}.unique_imported_events".freeze }.freeze

            EVENT_ATTRS = %w(service cinstance uinstance metric period timestamp time_gen).freeze
            JOIN_EVENT_ATTRS = (EVENT_ATTRS - ['time_gen']).freeze

            EXISTING_TABLES =
              'SELECT table_name '\
              'FROM information_schema.tables '\
              "WHERE table_schema = '#{SCHEMA}';".freeze

            CREATE_TEMP_TABLES =
              "DROP TABLE IF EXISTS #{TABLES[:temp]} CASCADE; "\
              "CREATE TABLE #{TABLES[:temp]} (LIKE #{TABLES[:events]}); "\
              "DROP TABLE IF EXISTS #{TABLES[:unique_imported_events]} CASCADE; "\
              "CREATE TABLE #{TABLES[:unique_imported_events]} (LIKE #{TABLES[:events]}); "\
              'COMMIT;'.freeze

            CLEAN_TEMP_TABLES =
              "DROP TABLE #{TABLES[:unique_imported_events]}; "\
              "DROP TABLE #{TABLES[:temp]};".freeze

            LATEST_TIMESTAMP_READ = "SELECT s3_path FROM #{TABLES[:latest_s3_path_read]}".freeze

            VACUUM = "VACUUM FULL #{TABLES[:events]}".freeze

            class << self

              def insert_imported_events
                'BEGIN TRANSACTION; '\
                  "DELETE FROM #{TABLES[:events]} "\
                  "USING #{TABLES[:unique_imported_events]} u "\
                  "WHERE #{TABLES[:events]}.timestamp >= "\
                  "(SELECT MIN(timestamp) FROM #{TABLES[:unique_imported_events]}) "\
                  "AND #{join_comparisons(TABLES[:events], 'u', JOIN_EVENT_ATTRS)} "\
                  "AND (#{TABLES[:events]}.time_gen < u.time_gen); "\
                  "INSERT INTO #{TABLES[:events]} "\
                  "SELECT * FROM #{TABLES[:unique_imported_events]};" \
                  'END TRANSACTION;'.freeze
              end

              # In order to get unique events, I use an inner-join with the same
              # table. There might be several rows with the same {service, instance,
              # uinstance, metric, period, timestamp} and different time_gen and
              # value. From those rows, we want to get just the one with the highest
              # time_gen. We cannot get the one with the highest value because we
              # support SET operations. That means that a value of '0' can be more
              # recent than '50'.
              #
              # The way to solve this is as follows: find out the max time_gen
              # grouping the 'repeated' events, and then perform an inner-join to
              # select the row with the most recent data.
              #
              # Note that we are only getting events with period != 'minute' and
              # service = master. This is what is required for the dashboard project.
              # We will need to change this when we start importing data to a
              # Redshift cluster used as a source for the stats API.
              def fill_table_unique_imported
                "INSERT INTO #{TABLES[:unique_imported_events]} "\
                  'SELECT e.service, e.cinstance, e.uinstance, e.metric, e.period, '\
                  'e.timestamp, e.time_gen, e.value '\
                  'FROM '\
                  '(SELECT service, cinstance, uinstance, metric, period, '\
                  'MAX(time_gen) AS max_time_gen, timestamp '\
                  "FROM #{TABLES[:temp]} "\
                  "WHERE period != 'minute' AND service = '#{master_service}' "\
                  'GROUP BY service, cinstance, uinstance, metric, period, timestamp) AS e1 '\
                  "INNER JOIN #{TABLES[:temp]} e "\
                  "ON #{join_comparisons('e', 'e1', JOIN_EVENT_ATTRS)} "\
                  'AND e.time_gen = e1.max_time_gen ' \
                  'GROUP BY e.service, e.cinstance, e.uinstance, e.metric, e.period, '\
                  'e.timestamp, e.time_gen, e.value'.freeze
              end

              # Once we have imported some events and have made sure that we have
              # selected only the ones that are more recent, we need to delete the
              # ones that do not need to be imported. Those are the ones that have
              # a time_gen older than that of the same event in the events table.
              def delete_outdated_from_unique_imported
                "DELETE FROM #{TABLES[:unique_imported_events]} "\
                  'USING (SELECT * '\
                  "FROM #{TABLES[:events]} e "\
                  'WHERE e.time_gen >= (SELECT MIN(time_gen) '\
                  "FROM #{TABLES[:unique_imported_events]})) AS e "\
                  "WHERE #{join_comparisons(
                TABLES[:unique_imported_events], 'e', JOIN_EVENT_ATTRS)} "\
                "AND (#{TABLES[:unique_imported_events]}.time_gen <= e.time_gen);".freeze
              end

              def import_s3_path(path, access_key_id, secret_access_key)
                "COPY #{TABLES[:temp]} "\
                  "FROM '#{path}' "\
                  "CREDENTIALS '#{amazon_credentials(access_key_id,
                                                 secret_access_key)}' "\
                                                 "FORMAT AS JSON 'auto' "\
                                                 "TIMEFORMAT 'auto';"
              end

              def delete_nulls_from_imported
                attrs_with_nulls = %w(cinstance uinstance)
                attrs_with_nulls.map do |attr|
                  replace_nulls(TABLES[:temp], attr, '')
                end.join(' ')
              end

              def store_timestamp_read(timestamp)
                "DELETE FROM #{TABLES[:latest_s3_path_read]}; "\
                  "INSERT INTO #{TABLES[:latest_s3_path_read]} VALUES ('#{timestamp}');"
              end

              def duplicated_events
                'SELECT COUNT(*) '\
                  'FROM (SELECT COUNT(*) AS count '\
                  "FROM #{TABLES[:events]} "\
                  "GROUP BY #{JOIN_EVENT_ATTRS.join(',')}) AS group_counts "\
                  'WHERE group_counts.count > 1;'
              end

              private

              def amazon_credentials(access_key_id, secret_access_key)
                "aws_access_key_id=#{access_key_id};"\
                  "aws_secret_access_key=#{secret_access_key}"
              end

              def replace_nulls(table, attr, value)
                "UPDATE #{table} "\
                  "SET #{attr} = '#{value}' "\
                  "WHERE #{attr} IS NULL;"
              end

              # Given 2 tables and an array of attributes, generates a string
              # like this:
              # table1.attr1 = table2.attr1 AND table1.attr2 = table2.attr2 AND ...
              # This is helpful to build the WHERE clauses of certain JOINs.
              def join_comparisons(table1, table2, attrs)
                attrs.map do |attr|
                  "#{table1}.#{attr} = #{table2}.#{attr}"
                end.join(' AND ') + ' '
              end

              def master_service
                Backend.configuration.master_service_id
              end

            end
          end

          # This private class is the responsible for calculating the S3 paths
          # that we have not imported to Redshift yet.
          class S3EventPaths

            # The events in our S3 bucket are classified in paths.
            # Paths are created every hour.
            DIR_CREATION_INTERVAL = 60*60
            private_constant :DIR_CREATION_INTERVAL

            # When we read a path we want to be sure that no more events will be stored
            # For that reason, we will wait a few minutes after the hour ends just to
            # be safe. For example, we will not read the path '2016/02/25/00' until
            # 2016-02-25 01:00 + DIR_BACKUP_TIME_S
            DIR_BACKUP_TIME_S = 60*10
            private_constant :DIR_BACKUP_TIME_S

            class << self

              def pending_paths(latest_read)
                time_now = Time.now.utc
                start_time = DateTime.parse(latest_read).to_time.utc + DIR_CREATION_INTERVAL

                (start_time.to_i..time_now.to_i).step(DIR_CREATION_INTERVAL).inject([]) do |res, time|
                  t = Time.at(time)
                  break res unless can_get_events?(time_now, t)
                  res << t.utc
                end
              end

              private

              def can_get_events?(now, time)
                now - time > DIR_CREATION_INTERVAL + DIR_BACKUP_TIME_S
              end

            end

          end
          private_constant :S3EventPaths

          S3_BUCKET = 'backend-events'.freeze
          private_constant :S3_BUCKET

          S3_EVENTS_BASE_PATH = "s3://#{S3_BUCKET}/".freeze
          private_constant :S3_EVENTS_BASE_PATH

          REQUIRED_TABLES = [SQL::TABLES[:events],
                             SQL::TABLES[:latest_s3_path_read]].freeze
          private_constant :REQUIRED_TABLES

          MissingRequiredTables = Class.new(ThreeScale::Backend::Error)
          MissingLatestS3PathRead = Class.new(ThreeScale::Backend::Error)

          class << self

            def insert_pending_events(silent = false)
              check_redshift_tables

              pending_times_utc = S3EventPaths.pending_paths(latest_timestamp_read)
              pending_times_utc.each do |pending_time_utc|
                puts "Loading events generated in hour: #{pending_time_utc}" unless silent
                save_in_redshift(s3_path(pending_time_utc))
                save_latest_read(pending_time_utc)
              end
              pending_times_utc.last
            end

            # This method import a specific S3 path into Redshift.
            # Right now, its main use case consists of uploading past events to
            # a path and importing only that path.
            def insert_path(path)
              # Need to check that the 'events' table exists. Do not care about
              # 'latest_s3_path_read' in this case.
              unless existing_tables_with_schema.include?(SQL::TABLES[:events])
                raise MissingRequiredTables, 'Events table is missing'
              end

              save_in_redshift("#{S3_EVENTS_BASE_PATH}#{path}")
            end

            # Returns a timestamp with format 'YYYYMMDDHH' or nil if the latest
            # timestamp read does not exist in the DB.
            def latest_timestamp_read
              query_result = execute_command(SQL::LATEST_TIMESTAMP_READ)
              return nil if query_result.ntuples == 0
              query_result.first['s3_path']
            end

            # Returns whether the data in the DB is consistent. Right now, this
            # method only checks if there are duplicated events, but it could be
            # extended in the future.
            def consistent_data?
              execute_command(SQL::duplicated_events).first['count'].to_i.zero?
            end

            private

            def config
              Backend.configuration
            end

            def redshift_config
              config.redshift.to_h
            end

            def redshift_connection
              @connection ||= PG::Connection.new(redshift_config)
            end

            def execute_command(command)
              redshift_connection.exec(command)
            end

            def check_redshift_tables
              unless required_tables_exist?
                raise MissingRequiredTables, 'Some of the required tables are not in Redshift.'
              end

              unless latest_timestamp_read_exists?
                raise MissingLatestS3PathRead,
                  "The 'latest read' table does not contain any values"
              end
            end

            def existing_tables
              execute_command(SQL::EXISTING_TABLES).map { |row| row['table_name'] }
            end

            def existing_tables_with_schema
              existing_tables.map { |table| "#{SQL::SCHEMA}.#{table}" }
            end

            def required_tables_exist?
              db_tables_with_schema = existing_tables_with_schema
              REQUIRED_TABLES.all? do |required_table|
                db_tables_with_schema.include?(required_table)
              end
            end

            def save_in_redshift(path)
              import_s3_path(path)
              [SQL.delete_nulls_from_imported,
               SQL.fill_table_unique_imported,
               SQL.delete_outdated_from_unique_imported,
               SQL.insert_imported_events,
               SQL::CLEAN_TEMP_TABLES,
               SQL::VACUUM].each { |command| execute_command(command) }
            end

            def save_latest_read(time_utc)
              execute_command(SQL.store_timestamp_read(time_utc.strftime('%Y%m%d%H')))
            end

            def import_s3_path(path)
              execute_command(SQL::CREATE_TEMP_TABLES)
              execute_command(SQL.import_s3_path(
                path, config.aws_access_key_id, config.aws_secret_access_key))
            end

            def latest_timestamp_read_exists?
              execute_command(SQL::LATEST_TIMESTAMP_READ).ntuples > 0
            end

            def s3_path(time_utc)
              "#{S3_EVENTS_BASE_PATH}#{time_utc.strftime('%Y/%m/%d/%H')}"
            end

          end

        end
      end
    end
  end
end
