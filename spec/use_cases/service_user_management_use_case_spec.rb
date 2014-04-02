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

      describe '#exists?' do
        it 'returns true if User is added to the Service' do
          ServiceUserManagementUseCase.new(service, 'foo').add

          expect(use_case.exists?).to be true
        end

        it "returns true if User isn't added to the Service" do
          expect(use_case.exists?).to be false
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

      describe '#count' do
        it 'returns number of Users in the Service' do
          ServiceUserManagementUseCase.new(service, 'foo').add

          expect(use_case.count).to eq 1
        end

        it 'returns 0 if there are no users' do
          expect(use_case.count).to eq 0
        end
      end

    end
  end
end

