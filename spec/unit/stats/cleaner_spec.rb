require_relative '../../../lib/3scale/backend/stats/stats_parser'

module ThreeScale
  module Backend
    module Stats
      describe Cleaner do
        include TestHelpers::Sequences

        let(:storage) { Backend::Storage.instance }
        let(:storage_instances) { storage.send(:proxied_instances) }
        let(:logger) { object_double(Backend.logger) }

        before do
          allow(logger).to receive(:info)
          allow(described_class).to receive(:logger).and_return(logger)
        end

        describe 'delete' do
          let(:services_to_be_deleted) do
            ['service_to_delete_1', 'service_to_delete_2']
          end

          # Defined according to the 2 services above
          let(:keys_to_be_deleted) do
            {
              # Stats keys, service level
              'stats/{service:service_to_delete_1}/metric:m1/day:20191216' => 10,
              'stats/{service:service_to_delete_2}/metric:m1/year:20190101' => 100,

              # Stats keys, app level
              'stats/{service:service_to_delete_1}/cinstance:app1/metric:m1/day:20191216' => 10,
              'stats/{service:service_to_delete_2}/cinstance:app1/metric:m1/year:20190101' => 100,

              # Response codes
              'stats/{service:service_to_delete_1}/response_code:200/day:20191216' => 2,
              'stats/{service:service_to_delete_2}/cinstance:app2/response_code:200/day:20191216' => 3
            }
          end

          # Notice that these do not belong to the 2 services defined above
          let(:keys_not_to_be_deleted) do
            non_stats_keys.merge(
              {
                # Stats keys, service level
                'stats/{service:s1}/metric:m1/day:20191216' => 10,
                'stats/{service:s1}/metric:m1/year:20190101' => 100,

                # Stats keys, app level
                'stats/{service:s1}/cinstance:app1/metric:m1/day:20191216' => 10,
                'stats/{service:s1}/cinstance:app1/metric:m1/year:20190101' => 100,

                # Response codes
                'stats/{service:s2}/response_code:200/day:20191216' => 2,
                'stats/{service:s2}/cinstance:app2/response_code:200/day:20191216' => 3
              }
            )
          end

          let(:all_keys) { keys_not_to_be_deleted.merge(keys_to_be_deleted) }

          let(:redis_set_marked_to_be_deleted) do
            described_class.const_get(:KEY_SERVICES_TO_DELETE)
          end

          before do # Fill Redis
            all_keys.each { |k, v| storage.set(k, v) }
          end

          context 'when there are services marked to be deleted' do
            before do
              services_to_be_deleted.each do |service|
                Cleaner.mark_service_to_be_deleted(service)
              end
            end

            it 'deletes only the stats of services marked to be deleted' do
              Cleaner.delete!(storage_instances)

              expect(keys_not_to_be_deleted.keys.all? { |key| storage.exists?(key) })
                .to be true

              expect(keys_to_be_deleted.keys.none? { |key| storage.exists?(key) })
                .to be true
            end

            it 'deletes the services from the set of marked to be deleted' do
              Cleaner.delete!(storage_instances)

              expect(storage.smembers(redis_set_marked_to_be_deleted)).to be_empty
            end
          end

          context 'when there are no services marked to be deleted' do
            before { storage.del(redis_set_marked_to_be_deleted) }

            it 'does not delete any keys' do
              expect(all_keys.keys.all? {|key| storage.exists?(key) })
            end
          end

          context 'with the option to log deleted keys enabled' do
            let(:log_to) { double(STDOUT) }

            before do
              allow(log_to).to receive(:puts)

              services_to_be_deleted.each do |service|
                Cleaner.mark_service_to_be_deleted(service)
              end
            end

            it 'logs the deleted keys, one per line' do
              Cleaner.delete!(storage_instances, log_deleted_keys: log_to)

              keys_to_be_deleted.each do |k, v|
                expect(log_to).to have_received(:puts).with("#{k} #{v}")
              end
            end

            it 'deletes only the stats of services marked to be deleted' do
              Cleaner.delete!(storage_instances, log_deleted_keys: log_to)

              expect(keys_not_to_be_deleted.keys.all? { |key| storage.exists?(key) })
                .to be true

              expect(keys_to_be_deleted.keys.none? { |key| storage.exists?(key) })
                .to be true
            end

            it 'deletes the services from the set of marked to be deleted' do
              Cleaner.delete!(storage_instances, log_deleted_keys: log_to)

              expect(storage.smembers(redis_set_marked_to_be_deleted)).to be_empty
            end
          end

          context 'when there are redis connection errors' do
            before do
              services_to_be_deleted.each do |service|
                Cleaner.mark_service_to_be_deleted(service)
              end

              allow(logger).to receive(:error)

              # Using scan just because it's the first command called.
              allow(storage_instances.first)
                .to receive(:scan).and_raise(Errno::ECONNREFUSED)
            end

            it 'logs an error without raising' do
              expect { Cleaner.delete!(storage_instances) }.not_to raise_error
              expect(logger).to have_received(:error)
            end

            it 'retries' do
              Cleaner.delete!(storage_instances)
              expect(storage_instances.first)
                .to have_received(:scan)
                .exactly(Cleaner.const_get(:MAX_RETRIES_REDIS_ERRORS)).times
            end
          end
        end

        describe '.delete_stats_keys_with_usage_0' do
          let(:stats_with_usage_0) do
            stats_keys = stats_keys_with_random_ids
            Hash[stats_keys.zip(Array.new(stats_keys.size, 0))]
          end

          let(:stats_with_non_zero_usage) do
            stats_keys = stats_keys_with_random_ids
            Hash[stats_keys.zip(Array.new(stats_keys.size, rand(1..10)))]
          end

          before do
            [stats_with_usage_0, stats_with_non_zero_usage, non_stats_keys].each do |key_vals|
              key_vals.each { |k, v| storage.set(k, v) }
            end
          end

          it 'deletes the stats with usage 0' do
            Cleaner.delete_stats_keys_set_to_0(storage_instances)
            expect(stats_with_usage_0.keys.none? { |k| storage.exists?(k) }).to be true
          end

          it 'does not delete the stats with usage != 0' do
            Cleaner.delete_stats_keys_set_to_0(storage_instances)
            expect(stats_with_non_zero_usage.keys.all? { |k| storage.exists?(k) }). to be true
          end

          it 'does not delete non-stats keys' do
            Cleaner.delete_stats_keys_set_to_0(storage_instances)
            expect(non_stats_keys.keys.all? { |k| storage.exists?(k) }).to be true
          end

          context 'with the option to log deleted keys enabled' do
            let(:log_to) { double(STDOUT) }

            before do
              allow(log_to).to receive(:puts)
            end

            it 'logs the deleted keys, one per line' do
              Cleaner.delete_stats_keys_set_to_0(
                storage_instances, log_deleted_keys: log_to
              )

              stats_with_usage_0.keys.each do |k|
                expect(log_to).to have_received(:puts).with(k)
              end
            end
          end

          context 'when there are redis connection errors' do
            before do
              allow(logger).to receive(:error)

              # Using scan just because it's the first command called.
              allow(storage_instances.first)
                .to receive(:scan).and_raise(Errno::ECONNREFUSED)
            end

            it 'logs an error without raising' do
              expect do
                Cleaner.delete_stats_keys_set_to_0(storage_instances)
              end.not_to raise_error

              expect(logger).to have_received(:error)
            end

            it 'retries' do
              Cleaner.delete_stats_keys_set_to_0(storage_instances)
              expect(storage_instances.first)
                .to have_received(:scan)
                .exactly(Cleaner.const_get(:MAX_RETRIES_REDIS_ERRORS)).times
            end
          end
        end

        private

        def non_stats_keys
          {
            k1: 'v1', k2: 'v2', k3: 'v3',

            # Starts with "stats/" but it's not a stats key, it's used for the
            # "first traffic" event.
            'stats/{service:s1}/cinstances' => 'some_val',

            # Legacy or corrupted keys that look like stats keys but should be
            # ignored.
            'stats/{service:s1}/city:/metric:m1/day:20191216' => 1, # 'city' no longer used
            'stats/{service:s1}/%?!`:m1/day:20191216' => 2, # corrupted.
          }
        end

        def stats_keys_with_random_ids
          [
            # Stats key, service level
            "stats/{service:#{next_id}}/metric:#{next_id}/day:20191216",

            # Stats key, app level
            "stats/{service:#{next_id}}/cinstance:#{next_id}/metric:#{next_id}/day:20191216",

            # Response codes
            "stats/{service:#{next_id}}/response_code:200/day:20191216",
            "stats/{service:#{next_id}}/cinstance:#{next_id}/response_code:200/day:20191216",
          ]
        end
      end
    end
  end
end
