require_relative '../../spec_helper'

module ThreeScale
  module Backend
    module Stats
      describe RedshiftImporter.const_get(:S3EventPaths) do
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

      describe RedshiftImporter do
        subject { described_class }

        let(:redshift_connection) { double }

        before do
          allow(subject)
              .to receive(:redshift_connection)
              .and_return redshift_connection
        end

        describe '.insert_data' do
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
                [subject.send(:create_temp_table_sql),
                 subject.send(:import_s3_path_sql,
                              subject.send(:s3_path, pending_paths.first)),
                 subject.send(:create_view_unique_imported_events_sql),
                 subject.send(:insert_imported_events_sql),
                 subject.send(:clean_temp_tables_sql),
                 subject.send(:store_timestamp_read_sql,
                              pending_paths.first.strftime('%Y%m%d%H'))]

              expected_sql_queries.each do |query|
                expect(redshift_connection).to receive(:exec).with(query).once
              end

              Timecop.freeze(current_time) { subject.insert_data(true) }
            end
          end

          context 'when the events table does not exist in Redshift' do
            before do
              allow(redshift_connection)
                  .to receive(:exec)
                  .with(subject.send(:existing_tables_sql))
                  .and_return [subject.const_get(:TABLES)[:latest_s3_path_read]]
            end

            it 'raises MissingRequiredTables exception' do
              expect { subject.insert_data }
                  .to raise_error subject::MissingRequiredTables
            end
          end

          context 'when the latest_s3_path_read table does not exist in Redshift' do
            before do
              allow(redshift_connection)
                  .to receive(:exec)
                  .with(subject.send(:existing_tables_sql))
                  .and_return [subject.const_get(:TABLES)[:events]]
            end

            it 'raises MissingRequiredTables exception' do
              expect { subject.insert_data }
                  .to raise_error subject::MissingRequiredTables
            end
          end

          context 'when the required tables exist but latest_s3_path_read is empty' do
            let(:existing_tables) do
              [subject.const_get(:TABLES)[:events],
               subject.const_get(:TABLES)[:latest_s3_path_read]]
            end

            before do
              allow(redshift_connection)
                  .to receive(:exec)
                  .with(subject.send(:existing_tables_sql))
                  .and_return existing_tables

              allow(redshift_connection)
                  .to receive(:exec)
                  .with(subject.send(:latest_timestamp_read_sql))
                  .and_return double(:query_result, ntuples: 0)
            end

            it 'raises MissingLatestS3PathRead exception' do
              expect { subject.insert_data }
                  .to raise_error subject::MissingLatestS3PathRead
            end
          end
        end
      end
    end
  end
end
