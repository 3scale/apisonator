require_relative '../spec_helper'

module ThreeScale
  module Backend
    describe CubertServiceManagementUseCase do
      let(:storage) { ThreeScale::Backend::Storage.instance }
      let(:enabled_service) { described_class.enable_service '7001', 'foo'; '7001' }
      let(:disabled_service) { '7002' }

      describe '.disable_service' do
        before do
          described_class.disable_service enabled_service
        end

        it 'deletes the bucket' do
          expect(described_class.bucket enabled_service).to be nil
        end

        it 'disables the service' do
          expect(described_class.enabled? enabled_service).to be false
        end
      end

      describe '.enable_service' do
        before do
          described_class.global_enable
          described_class.enable_service disabled_service, 'foo'
        end

        it 'enables service' do
          expect(described_class.enabled? disabled_service).to be_truthy
        end

        it 'create a bucket if needed' do
          expect(described_class.bucket disabled_service).not_to be_nil
        end

        it 'assigns a specified bucket' do
          described_class.enable_service(disabled_service, 'foobar')
          expect(described_class.bucket disabled_service).to eq('foobar')
        end
      end

      describe '.clean_cubert_redis_keys' do
        before do
          described_class.global_enable
          enabled_service
          described_class.clean_cubert_redis_keys
        end

        it 'removes all the keys' do
          expect(storage.get described_class.send(:global_lock_key)).to be_nil
          expect(described_class.bucket enabled_service).to be_nil
        end
      end

    end
  end
end
