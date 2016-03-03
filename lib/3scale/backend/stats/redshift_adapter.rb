require 'pg'

module ThreeScale
  module Backend
    module Stats

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
      #  2) Perform the necessary operations in the temp table to remove
      #     duplicates. (In our case this basically consists of an inner-join).
      #  3) Inside a transaction, delete all the events that are in the temp
      #     table from the final table. Next, insert the ones in the temp
      #     table into the final table. Finally, remove the temp table.
      class RedshiftAdapter

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

        # This importer relies on some tables or views that are created in
        # Redshift to function correctly.
        TABLES = { events: 'events'.freeze,
                   latest_s3_path_read: 'latest_s3_path_read'.freeze,
                   temp: 'temp_events'.freeze,
                   unique_imported_events: 'unique_imported_events'.freeze }
        private_constant :TABLES

        S3_BUCKET = 'backend-events'.freeze
        private_constant :S3_BUCKET

        S3_EVENTS_BASE_PATH = "s3://#{S3_BUCKET}/".freeze
        private_constant :S3_EVENTS_BASE_PATH

        REQUIRED_TABLES = [TABLES[:events], TABLES[:latest_s3_path_read]].freeze
        private_constant :REQUIRED_TABLES

        MissingRequiredTables = Class.new(ThreeScale::Backend::Error)
        MissingLatestS3PathRead = Class.new(ThreeScale::Backend::Error)

        class << self

          def insert_data(silent = false)
            check_redshift_tables

            pending_times_utc = S3EventPaths.pending_paths(latest_timestamp_read)
            pending_times_utc.each do |pending_time_utc|
              puts "Loading events generated in hour: #{pending_time_utc}" unless silent

              import_s3_path(pending_time_utc)
              create_view_unique_imported_events
              insert_imported_events
              clean_temp_tables
              store_timestamp_read(pending_time_utc.strftime('%Y%m%d%H'))
            end
          end

          private

          def config
            Backend.configuration
          end

          def redshift_config
            config.redshift.to_h
          end

          def redshift_connection
            @connection ||= PGconn.new(redshift_config)
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
            execute_command(existing_tables_sql)
          end

          def required_tables_exist?
            db_tables = existing_tables
            REQUIRED_TABLES.all? do |required_table|
              db_tables.include?(required_table)
            end
          end

          def import_s3_path(time_utc)
            execute_command(create_temp_table_sql)
            path = s3_path(time_utc)
            execute_command(import_s3_path_sql(path))
          end

          def create_view_unique_imported_events
            execute_command(create_view_unique_imported_events_sql)
          end

          def insert_imported_events
            execute_command(insert_imported_events_sql)
          end

          def clean_temp_tables
            execute_command(clean_temp_tables_sql)
          end

          def store_timestamp_read(timestamp)
            execute_command(store_timestamp_read_sql(timestamp))
          end

          def latest_timestamp_read
            execute_command(latest_timestamp_read_sql).first['s3_path']
          end

          def latest_timestamp_read_exists?
            execute_command(latest_timestamp_read_sql).ntuples > 0
          end

          def existing_tables_sql
            "SELECT DISTINCT tablename
             FROM pg_table_def
             WHERE schemaname = 'public'
             ORDER BY tablename;"
          end

          def create_temp_table_sql
            "DROP TABLE IF EXISTS #{TABLES[:temp]} CASCADE;
             CREATE TABLE #{TABLES[:temp]} (LIKE #{TABLES[:events]});
             COMMIT;"
          end

          def import_s3_path_sql(path)
            "COPY #{TABLES[:temp]}
               FROM '#{path}'
               CREDENTIALS '#{amazon_credentials}'
               FORMAT AS JSON 'auto'
               TIMEFORMAT 'auto';"
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
          def create_view_unique_imported_events_sql
            "CREATE VIEW #{TABLES[:unique_imported_events]} AS
                SELECT e.service, e.cinstance, e.uinstance, e.metric, e.period,
                  e.timestamp, e.time_gen, e.value
                FROM
                  (SELECT service, cinstance, uinstance, metric, period,
                     MAX(time_gen) AS max_time_gen, timestamp
                    FROM #{TABLES[:temp]}
                    WHERE period != 'minute' /* minutes not needed for the dashboard project */
                    GROUP BY service, cinstance, uinstance, metric, period, timestamp) AS e1
                  INNER JOIN #{TABLES[:temp]} e
                    ON (e.service = e1.service)
                      AND (e.cinstance = e1.cinstance
                        OR (e.cinstance IS NULL AND e1.cinstance IS NULL))
                      AND (e.uinstance = e1.uinstance
                        OR (e.uinstance IS NULL AND e1.uinstance IS NULL))
                      AND (e.metric = e1.metric)
                      AND (e.period = e1.period)
                      AND (e.timestamp = e1.timestamp)
                      AND (e.time_gen = e1.max_time_gen);"
          end

          def insert_imported_events_sql
            "BEGIN TRANSACTION;

              DELETE FROM #{TABLES[:events]}
              USING #{TABLES[:unique_imported_events]} u
              WHERE #{TABLES[:events]}.service = u.service
                AND (#{TABLES[:events]}.cinstance = u.cinstance
                  OR (#{TABLES[:events]}.cinstance IS NULL AND u.cinstance IS NULL))
                AND (#{TABLES[:events]}.uinstance = u.uinstance
                  OR (#{TABLES[:events]}.uinstance IS NULL AND u.uinstance IS NULL))
                AND (#{TABLES[:events]}.metric = u.metric)
                AND (#{TABLES[:events]}.period = u.period)
                AND (#{TABLES[:events]}.timestamp = u.timestamp)
                AND (#{TABLES[:events]}.time_gen < u.time_gen);

              INSERT INTO events
                SELECT * FROM unique_imported_events;

            END TRANSACTION;"
          end

          def clean_temp_tables_sql
            "DROP VIEW #{TABLES[:unique_imported_events]};
             DROP TABLE #{TABLES[:temp]};"
          end

          def store_timestamp_read_sql(timestamp)
            "DELETE FROM #{TABLES[:latest_s3_path_read]};
             INSERT INTO #{TABLES[:latest_s3_path_read]} VALUES ('#{timestamp}');"
          end

          def latest_timestamp_read_sql
            "SELECT s3_path FROM #{TABLES[:latest_s3_path_read]}"
          end

          def s3_path(time_utc)
            "#{S3_EVENTS_BASE_PATH}#{time_utc.strftime('%Y/%m/%d/%H')}"
          end

          def amazon_credentials
            "aws_access_key_id=#{config.aws_access_key_id};"\
              "aws_secret_access_key=#{config.aws_secret_access_key}"
          end

        end

      end

    end
  end
end
