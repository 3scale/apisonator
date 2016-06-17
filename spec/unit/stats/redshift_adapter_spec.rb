require_relative '../../spec_helper'

module ThreeScale
  module Backend
    module Stats
      class RedshiftAdapter
        class << self
          private

          # Instead of importing a path from S3, in these tests we just want to
          # insert some events directly into the table of imported events.
          # There are 2 reasons for that:
          # 1) We are not interested in testing that we can import from S3.
          # 2) To import from S3, Redshift uses the COPY command, which is not
          #    available in Postgres.
          def import_s3_path(_path); end
        end
      end

      describe RedshiftAdapter.const_get(:S3EventPaths) do
        subject { described_class }

        describe '.pending_paths' do
          context 'when the timestamp of the latest path read is from the past' do
            let(:current_time) { DateTime.parse('2016010110') }
            let(:latest_read) { '2016010106' }

            it 'returns the pending paths that are closed' do
              Timecop.freeze(current_time) do
                expect(subject.pending_paths(latest_read))
                    .to eq [DateTime.parse('2016010107').to_time.utc,
                            DateTime.parse('2016010108').to_time.utc]
              end
            end
          end

          context 'when the timestamp of the latest path read is from the future' do
            let(:current_time) { DateTime.parse('2016010100').to_time.utc }
            let(:future_time) { current_time + 60*60 }
            let(:latest_read_timestamp) { future_time.strftime('%Y%m%d%H') }

            it 'returns an empty array' do
              Timecop.freeze(current_time) do
                expect(subject.pending_paths(latest_read_timestamp)).to be_empty
              end
            end
          end
        end
      end

      # These tests use an instance of Postgres running in the development
      # container. We though that unit test are not sufficient to guarantee
      # that everything works as expected in this case because we would need
      # to mock too many things.
      describe RedshiftAdapter do
        before(:all) do
          @redshift = RedshiftAdapter.send(:redshift_connection)

          # Disable notices in the output. pg prints some warnings for example
          # when executing 'DROP TABLE IF EXISTS' with a table that does not
          # exists. In these tests we do not want to print those kind of
          # warnings.
          @redshift.set_notice_receiver { |_| }
        end

        after(:all) { clean_up }

        subject { described_class }

        let(:tables) { subject::SQL::TABLES }
        let(:latest_path) { '2016010100' } # Value not important

        # We are only exporting services with id = master. So the events we use
        # in this test must belong to that service.
        let(:master_service) { Backend.configuration.master_service_id }

        let(:timestamp) { '2016-04-01 00:00:00' }
        let(:newer_timestamp) { '2016-05-01 00:00:00' }

        # Events have lots of fields. To simplify tests and not declare many
        # events, we are going to define a base event. That way, if in a test
        # we need to use 2 different events, it is as simple as using
        # 'example_event' and 'example_event.merge(field_to_change: value)'.
        # The values are not relevant to these tests except 'timestamp'
        # and 'time_gen'.
        let(:example_event) do
          { service: master_service, cinstance: 'a', uinstance: 'b',
            metric: 20, period: 'month', timestamp: timestamp,
            time_gen: timestamp, value: 100 }
        end

        describe '.insert_path' do
          let(:path) { 'path' } # Value not important

          before do
            clean_up
            create_schema
            create_tables

            # We need a latest imported. Does not matter which one.
            @redshift.exec("INSERT INTO #{tables[:latest_s3_path_read]} VALUES ('#{latest_path}')")

            insert_events(pending_events, tables[:temp])
          end

          context 'when all the events need to be imported (there are no duplicates or outdated)' do
            let(:pending_events) do
              [example_event, example_event.merge(metric: 30)]
            end

            it 'imports all of them' do
              subject.insert_path(path)
              expect(events_from_db(tables[:events]))
                  .to contain_exactly *pending_events
            end
          end

          context 'when some of the pending events appear more than once (different time_gen)' do
            let(:old_event) { example_event }
            let(:new_event) { example_event.merge(time_gen: newer_timestamp) }
            let(:pending_events) { [old_event, new_event] }

            it 'does not import repeated events, just the most recent version of each' do
              subject.insert_path(path)
              expect(events_from_db(tables[:events]))
                  .to contain_exactly new_event
            end
          end

          context 'when some of the pending events appear more than once (same time_gen)' do
            let(:pending_events) { Array.new(2, example_event) }

            it 'imports all of them without duplicates' do
              subject.insert_path(path)
              expect(events_from_db(tables[:events]))
                  .to contain_exactly example_event
            end
          end

          context 'when an event of the pending ones exists and it is outdated' do
            let(:old_event) { example_event }
            let(:new_event) { example_event.merge(time_gen: newer_timestamp) }
            let(:pending_events) { [new_event] }

            before { insert_events([old_event], tables[:temp]) }

            it 'imports it to have the most recent value' do
              subject.insert_path(path)
              expect(events_from_db(tables[:events]))
                  .to contain_exactly new_event
            end
          end

          context 'when an event of the pending ones exists and it is not outdated' do
            let(:old_event) { example_event }
            let(:new_event) { example_event.merge(time_gen: newer_timestamp) }
            let(:pending_events) { [old_event] }

            before { insert_events([new_event], tables[:temp]) }

            it 'does not import it, because we already have a more recent value' do
              subject.insert_path(path)
              expect(events_from_db(tables[:events]))
                  .to contain_exactly new_event
            end
          end

          context 'when a pending event has null in some attributes' do
            let(:event_with_null_cinstance) { example_event.merge(cinstance: nil) }
            let(:pending_events) { [event_with_null_cinstance] }

            it 'imports the event but replaces nulls with empty string' do
              subject.insert_path(path)
              expect(events_from_db(tables[:events]))
                  .to contain_exactly event_with_null_cinstance.merge(cinstance: '')
            end
          end

          context 'when the events table does not exist in Redshift' do
            let(:pending_events) { [] }

            before { drop_table(tables[:events]) }

            it 'raises MissingRequiredTables exception' do
              expect { subject.insert_path(path) }
                  .to raise_error subject::MissingRequiredTables
            end
          end
        end

        describe '.insert_pending_events' do
          # For this method we are only interested in performing tests that
          # check that some exceptions are raised. The reason is that the
          # 'happy path' has already been tested in '.insert_path'.
          # The two methods are equivalent, except for the fact that this one
          # automatically detects which S3 paths are pending to be imported,
          # and we are not interested in testing that part here.

          before do
            clean_up
            create_schema
            create_tables

            # We need a latest imported. Does not matter which one.
            @redshift.exec("INSERT INTO #{tables[:latest_s3_path_read]} VALUES ('#{latest_path}')")
          end

          context 'when the events table does not exist in Redshift' do
            before { drop_table(tables[:events]) }

            it 'raises MissingRequiredTables exception' do
              expect { subject.insert_pending_events }
                  .to raise_error subject::MissingRequiredTables
            end
          end

          context 'when the latest_s3_path_read table does not exist in Redshift' do
            before { drop_table(tables[:latest_s3_path_read]) }

            it 'raises MissingRequiredTables exception' do
              expect { subject.insert_pending_events }
                  .to raise_error subject::MissingRequiredTables
            end
          end

          context 'when the required tables exist but latest_s3_path_read is empty' do
            before { empty_table(tables[:latest_s3_path_read]) }

            it 'raises MissingLatestS3PathRead exception' do
              expect { subject.insert_pending_events }
                  .to raise_error subject::MissingLatestS3PathRead
            end
          end
        end

        describe '.latest_timestamp_read' do
          before { empty_table(tables[:latest_s3_path_read]) }

          context 'when there is a latest read' do
            let(:latest) { '2016030912' }

            before do
              @redshift.exec("INSERT INTO #{tables[:latest_s3_path_read]} VALUES (#{latest})")
            end

            it 'returns the latest S3 path read' do
              expect(subject.latest_timestamp_read).to eq latest
            end
          end

          context 'when there is not a latest read' do
            it 'returns nil' do
              expect(subject.latest_timestamp_read).to be_nil
            end
          end
        end

        describe '.consistent_data?' do
          before do
            clean_up
            create_schema
            create_tables
            insert_events(events, tables[:events])
          end

          context 'when there are duplicated events' do
            let(:events) { Array.new(2, example_event) }

            it 'returns false' do
              expect(subject.consistent_data?).to be false
            end
          end

          context 'when there are no duplicated events' do
            let(:events) { [example_event, example_event.merge(metric: 30)] }

            it 'returns true' do
              expect(subject.consistent_data?).to be true
            end
          end
        end

        def clean_up
          drop_schema
        end

        def create_schema
          @redshift.exec('CREATE SCHEMA backend;')
        end

        def create_tables
          @redshift.exec('CREATE TABLE backend.events ('\
                          'service     bigint,'\
                          'cinstance   varchar(85),'\
                          'uinstance   varchar(70),'\
                          'metric      bigint,'\
                          'period      varchar(6),'\
                          'timestamp   timestamp,'\
                          'time_gen    timestamp,'\
                          'value       bigint);')
          @redshift.exec('CREATE TABLE backend.latest_s3_path_read (s3_path varchar(10));')
          @redshift.exec('CREATE TABLE backend.temp_events (LIKE backend.events);')
          @redshift.exec('CREATE TABLE backend.unique_imported_events (LIKE backend.events);')
        end

        def drop_schema
          @redshift.exec('DROP SCHEMA IF EXISTS backend CASCADE;')
        end

        def drop_table(table)
          @redshift.exec("DROP TABLE IF EXISTS #{table}")
        end

        def empty_table(table)
          @redshift.exec("DELETE FROM #{table}")
        end

        def insert_events(events, table)
          unless events.empty?
            @redshift.exec("INSERT INTO #{table} VALUES #{insert_values_format(events)}")
          end
        end

        def insert_values_format(events)
          events.map do |event|
            event_formatted = '('

            event_formatted << event_attrs.map do |attr|
              if event[attr]
                event[attr].is_a?(String) ? "'#{event[attr]}'" : event[attr]
              else
                'NULL'
              end
            end.join(',')

            event_formatted << ')'
          end.join(',')
        end

        def event_attrs
          [:service, :cinstance, :uinstance, :metric, :period,
           :timestamp, :time_gen, :value].freeze
        end

        def required_tables
          %w(backend.events
             backend.latest_s3_path_read
             backend.temp_events
             backend.unique_imported_events).freeze
        end

        def events_from_db(table)
          query_res = @redshift.exec("SELECT * FROM #{table}")
          events_from_query_res(query_res)
        end

        def events_from_query_res(result)
          rows = result.map { |row| row }
          rows.map do |row|
            attrs = row.map do |(k, v)|
              # Even if it is an int in the DB, pg returns string
              val = Integer(v) rescue v
              [k.to_sym, val]
            end

            Hash[attrs]
          end
        end
      end
    end
  end
end
