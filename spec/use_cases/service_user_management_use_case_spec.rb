require_relative '../spec_helper'

module ThreeScale
  module Backend
    describe ServiceUserManagementUseCase do
      let(:service){ Service.save! id: 7001, provider_key: 'random' }
      let(:use_case){ ServiceUserManagementUseCase.new(service, 'foo') }

      describe '#add' do
        it 'adds a User to a Service' do
          use_case.add

          expect(ServiceUserManagementUseCase.new(service, 'foo').exists?).to be true
        end

        it 'returns true when User has been added' do
          expect(use_case.add).to be true
        end

        it 'returns false when User was already added' do
          ServiceUserManagementUseCase.new(service, 'foo').add

          expect(use_case.add).to be false
        end
      end

      describe '#delete' do
        it 'deletes a User from a Service' do
          ServiceUserManagementUseCase.new(service, 'foo').add
          use_case.delete

          expect(ServiceUserManagementUseCase.new(service, 'foo').exists?).to be false
        end

        it 'returns true when User has been deleted' do
          ServiceUserManagementUseCase.new(service, 'foo').add

          expect(use_case.delete).to be true
        end

        it "returns false when User wasn't added" do
          expect(use_case.delete).to be false
        end
      end

    end
  end
end

