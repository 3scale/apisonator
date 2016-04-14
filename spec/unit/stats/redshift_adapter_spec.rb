require_relative '../../spec_helper'

module ThreeScale
  module Backend
    module Stats
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

      describe RedshiftAdapter do
        subject { described_class }

        let(:redshift_connection) { double }

        before do
          allow(subject)
              .to receive(:redshift_connection)
              .and_return redshift_connection
        end

        describe '.insert_pending_events' do
          context 'when the required tables exists in Redshift and latest_s3_path is not empty' do
            let(:current_time) { DateTime.parse('201601011450').to_time.utc }
            let(:latest_timestamp_read) { '2016010112' } # Only '2016010113' is pending
            let(:pending_paths) { [DateTime.parse('2016010113').to_time.utc] }

            before do
              allow(subject).to receive(:check_redshift_tables).and_return true

              allow(subject)
                  .to receive(:latest_timestamp_read)
                  .and_return latest_timestamp_read
            end

            it 'executes the necessary queries to perform an UPSERT' do
              expected_sql_queries =
                [subject::SQL::CREATE_TEMP_TABLE,
                 subject::SQL.import_s3_path(
                     subject.send(:s3_path, pending_paths.first), '', ''),
                 subject::SQL::CREATE_VIEW_UNIQUE_IMPORTED_EVENTS,
                 subject::SQL::INSERT_IMPORTED_EVENTS,
                 subject::SQL::CLEAN_TEMP_TABLES,
                 subject::SQL::VACUUM,
                 subject::SQL.store_timestamp_read(
                     pending_paths.first.strftime('%Y%m%d%H'))]

              expected_sql_queries.each do |query|
                expect(redshift_connection).to receive(:exec).with(query).once.ordered
              end

              Timecop.freeze(current_time) { subject.insert_pending_events(true) }
            end
          end

          context 'when the events table does not exist in Redshift' do
            before do
              # The `tables` hash contains all the names with the schema
              # included. However, the result of the query that checks the
              # existing tables in a schema does not contain it. This is
              # why we need to call `table_name_without_schema`.
              allow(redshift_connection)
                  .to receive(:exec)
                  .with(subject::SQL::EXISTING_TABLES)
                  .and_return [{ 'table_name' => table_name_without_schema(
                      subject::SQL::TABLES[:latest_s3_path_read]) }]
            end

            it 'raises MissingRequiredTables exception' do
              expect { subject.insert_pending_events }
                  .to raise_error subject::MissingRequiredTables
            end
          end

          context 'when the latest_s3_path_read table does not exist in Redshift' do
            before do
              allow(redshift_connection)
                  .to receive(:exec)
                  .with(subject::SQL::EXISTING_TABLES)
                  .and_return [{ 'table_name' => table_name_without_schema(
                      subject::SQL::TABLES[:events]) }]
            end

            it 'raises MissingRequiredTables exception' do
              expect { subject.insert_pending_events }
                  .to raise_error subject::MissingRequiredTables
            end
          end

          context 'when the required tables exist but latest_s3_path_read is empty' do
            let(:existing_tables) do
              [table_name_without_schema(subject::SQL::TABLES[:events]),
               table_name_without_schema(subject::SQL::TABLES[:latest_s3_path_read])]
            end

            before do
              allow(redshift_connection)
                  .to receive(:exec)
                  .with(subject::SQL::EXISTING_TABLES)
                  .and_return (existing_tables.map { |table| { 'table_name' => table } })

              allow(redshift_connection)
                  .to receive(:exec)
                  .with(subject::SQL::LATEST_TIMESTAMP_READ)
                  .and_return double(:query_result, ntuples: 0)
            end

            it 'raises MissingLatestS3PathRead exception' do
              expect { subject.insert_pending_events }
                  .to raise_error subject::MissingLatestS3PathRead
            end
          end
        end

        describe '.insert_path' do
          context 'when the events table does not exist in Redshift' do
            before do
              allow(redshift_connection)
                  .to receive(:exec)
                  .with(subject::SQL::EXISTING_TABLES)
                  .and_return []
            end

            it 'raises MissingRequiredTables exception' do
              expect { subject.insert_pending_events }
                  .to raise_error subject::MissingRequiredTables
            end
          end

          context 'when the events table exists in Redshift' do
            let(:path) { 'a_path' }

            before do
              allow(subject)
                  .to receive(:existing_tables_with_schema)
                  .and_return [subject::SQL::TABLES[:events]]
            end

            it 'executes the necessary queries to perform an UPSERT' do
              expected_sql_queries =
                  [subject::SQL::CREATE_TEMP_TABLE,
                   subject::SQL.import_s3_path(
                       "#{subject.const_get(:S3_EVENTS_BASE_PATH)}#{path}", '', ''),
                   subject::SQL::CREATE_VIEW_UNIQUE_IMPORTED_EVENTS,
                   subject::SQL::INSERT_IMPORTED_EVENTS,
                   subject::SQL::CLEAN_TEMP_TABLES,
                   subject::SQL::VACUUM]

              expected_sql_queries.each do |query|
                expect(redshift_connection).to receive(:exec).with(query).once.ordered
              end

              subject.insert_path(path)
            end
          end
        end

        describe '.latest_timestamp_read' do
          let(:latest_s3_path_read) { '2016030912' }

          context 'when there is a latest read' do
            before do
              allow(redshift_connection)
                  .to receive(:exec)
                  .with(subject::SQL::LATEST_TIMESTAMP_READ)
                  .and_return double(ntuples: 1,
                                     first: { 's3_path' => latest_s3_path_read })
            end

            it 'returns the latest S3 path read' do
              expect(subject.latest_timestamp_read).to eq latest_s3_path_read
            end
          end

          context 'when there is not a latest read' do
            before do
              allow(redshift_connection)
                  .to receive(:exec)
                  .with(subject::SQL::LATEST_TIMESTAMP_READ)
                  .and_return double(ntuples: 0)
            end

            it 'returns nil' do
              expect(subject.latest_timestamp_read).to be_nil
            end
          end
        end

        private

        def table_name_without_schema(name)
          name.sub(/^#{subject::SQL::SCHEMA}\./, '')
        end
      end
    end
  end
end
