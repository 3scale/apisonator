require_relative '../spec_helper'

module ThreeScale
  module Backend
    describe CubertServiceManagementUseCase do
      let(:storage) { ThreeScale::Backend::Storage.instance }
      let(:use_case){ CubertServiceManagementUseCase }
      let(:enabled_service) { use_case.new('7001').enable_service('foo'); '7001' }
      let(:disabled_service) { '7002' }

      describe '.disable_service' do
        before do
          @service = use_case.new enabled_service
          @service.disable_service
        end

        it 'deletes the bucket' do
          expect(@service.bucket).to be nil
        end

        it 'disables the service' do
          expect(@service.enabled?).to be false
        end
      end

      describe '.enable_service' do
        before do
          use_case.global_enable
          @service = use_case.new(disabled_service)
          @service.enable_service 'foo'
        end

        it 'enables service' do
          expect(@service.enabled?).to be_truthy
        end

        it 'create a bucket if needed' do
          expect(@service.bucket).not_to be nil
        end

        it 'assigns a specified bucket' do
          @service.enable_service 'foobar'
          expect(@service.bucket).to eq('foobar')
        end
      end

      describe '.clean_cubert_redis_keys' do
        before do
          use_case.global_enable
          enabled_service
          use_case.clean_cubert_redis_keys
        end

        it 'removes all the keys' do
          expect(storage.get use_case.global_lock_key).to be nil
          expect(use_case.new(enabled_service).bucket).to be nil
        end
      end

    end
  end
end

