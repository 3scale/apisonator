require_relative '../spec_helper'

module ThreeScale
  module Backend
    describe CubertServiceManagementUseCase do
      let(:storage) { ThreeScale::Backend::Storage.instance }
      let(:service_id) { '7001' }

      describe '.enable_service' do
        before do
          described_class.clean_cubert_redis_keys
          described_class.global_enable
          described_class.disable_service service_id
          described_class.enable_service service_id, 'foo'
        end

        it 'enables service' do
          expect(described_class.enabled? service_id).to be_truthy
        end

        it 'create a bucket if needed' do
          expect(described_class.bucket service_id).not_to be_nil
        end

        it 'assigns a specified bucket' do
          described_class.enable_service(service_id, 'foobar')
          expect(described_class.bucket service_id).to eq('foobar')
        end

        it 'adds an entry to the tracking set' do
          expect(storage.sismember(
            described_class.send(:all_bucket_keys_key),
            described_class.send(:bucket_id_key, service_id))).to be_truthy
        end
      end

      describe '.disable_service' do
        before do
          described_class.clean_cubert_redis_keys
          described_class.global_enable
          described_class.enable_service service_id, 'foo'
          described_class.disable_service service_id
        end

        it 'deletes the bucket' do
          expect(described_class.bucket service_id).to be_nil
        end

        it 'disables the service' do
          expect(described_class.enabled? service_id).to be_falsey
        end

        it 'does not leak an entry in the tracking set' do
          expect(storage.sismember(
            described_class.send(:all_bucket_keys_key),
            described_class.send(:bucket_id_key, service_id))).to be_falsey
        end
      end

      describe '.clean_cubert_redis_keys' do
        before do
          described_class.clean_cubert_redis_keys
          described_class.global_enable
          described_class.enable_service service_id, 'foo'
          described_class.clean_cubert_redis_keys
        end

        it 'removes all the keys' do
          expect(storage.exists described_class.send(:global_lock_key)).to be_falsey
          expect(storage.exists described_class.send(:global_lock_key)).to be_falsey
          expect(storage.exists described_class.send(:all_bucket_keys_key)).to be_falsey
          expect(described_class.bucket service_id).to be_nil
        end
      end

    end
  end
end
