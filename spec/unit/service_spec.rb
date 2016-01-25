require_relative '../spec_helper'

module ThreeScale
  module Backend
    describe Service do

      describe '.default_id' do
        before { Service.storage.set('service/provider_key:foo/id', '7001') }

        it 'returns an ID' do
          expect(Service.default_id('foo')).to eq '7001'
        end
      end

      describe '.load_by_id' do
        let(:service) do
          Service.save!(
            provider_key: 'foo', id: '7001', referrer_filters_required: 1
          )
        end
        let(:result){ Service.load_by_id(service.id) }

        it 'returns a Service object' do
          expect(result).to be_a(Service)
        end

        it 'returns nil when ID not found' do
          expect(Service.load_by_id('1234')).to be nil
        end

        it 'loads correct data' do
          expect(result.provider_key).to eq 'foo'
          expect(result.id).to eq '7001'
          expect(result.backend_version).to be nil
        end

        it 'changes filters_required field to a Boolean' do
          expect(result.referrer_filters_required?).to be true
        end

        describe 'user_registration_required' do
          it 'defaults to true when not set' do
            service = Service.save!(provider_key: 'foo', id: '7001')
            result = Service.load_by_id(service.id)

            expect(result.user_registration_required?).to be true
          end

          it 'changes to Boolean when set to Integer' do
            service = Service.save!(
              provider_key: 'foo', id: '7001', user_registration_required: 1)
            result = Service.load_by_id(service.id)

            expect(result.user_registration_required?).to be true
          end

          it 'is false when set to false' do
            service = Service.save!(provider_key: 'foo', id: '7001',
              user_registration_required: false, default_user_plan_id: '1001',
              default_user_plan_name: "user_plan_name")
            result = Service.load_by_id(service.id)

            expect(result.user_registration_required?).to be false
          end
        end
      end

      describe '.exists?' do
        let(:service) do
          Service.save!(provider_key: 'foo', id: '7001')
        end
        let(:existing_service_id) { service.id }
        let(:non_existing_service_id) { service.id.to_i.succ.to_s }

        it 'returns true when the service exists' do
          expect(Service.exists?(existing_service_id)).to be true
        end

        it 'returns false when the service does not exist' do
          expect(Service.exists?(non_existing_service_id)).to be false
        end
      end

      describe '.list' do
        it 'returns an array of IDs' do
          Service.save! provider_key: 'foo', id: '7001'
          Service.save! provider_key: 'foo', id: '7002'

          expect(Service.list('foo')).to eq ['7001', '7002']
        end

        it 'returns an empty array when none found' do
          expect(Service.list('foo')).to be_empty
        end
      end

      describe '.save!' do
        it 'returns a Service object' do
          expect(Service.save!(provider_key: 'foo', id: 7001)).to be_a(Service)
        end

        it 'stores Service data' do
          Service.save! provider_key: 'foo', id: 7001

          expect(Service.load_by_id(7001).provider_key).to eq 'foo'
        end

        describe 'default service' do
          before { Service.save! id: 7001, provider_key: 'foo' }

          it 'is updated when requested' do
            Service.save! id: 7002, provider_key: 'foo', default_service: true

            expect(Service.default_id('foo')).to eq '7002'
          end

          it 'isn\'t changed if not set' do
            Service.save! id: 7002, provider_key: 'foo'

            expect(Service.default_id('foo')).to eq '7001'
          end
        end

        describe 'user_registration_required massaging' do
          it 'sets the attibute to false when already false' do
            Service.save!(provider_key: 'foo', id: 7001,
              user_registration_required: false, default_user_plan_id: '1001',
              default_user_plan_name: "user_plan_name")

            expect(Service.load_by_id(7001).user_registration_required?).to be false
          end

          it 'sets the attibute to true when nil' do
            Service.save!(provider_key: 'foo', id: 7001, user_registration_required: nil)

            expect(Service.load_by_id(7001).user_registration_required?).to be true
          end

          it 'sets the attibute to true when already true' do
            Service.save!(provider_key: 'foo', id: 7001, user_registration_required: true)

            expect(Service.load_by_id(7001).user_registration_required?).to be true
          end
        end
      end

      describe '#save!' do
        let(:service){ Service.new(provider_key: 'foo', id: '7001') }

        it 'returns a Service object' do
          expect(service.save!).to be_a(Service)
        end

        it 'persists data' do
          service.save!

          expect(Service.load_by_id(service.id).provider_key).to eq 'foo'
        end

        it 'sets as default when none exists' do
          service.save!

          expect(Service.default_id('foo')).to eq service.id
        end

        it 'doesn\'t set as default when one exists' do
          Service.save!(provider_key: 'foo', id: '7002')
          service.save!

          expect(Service.default_id('foo')).not_to eq service.id
        end

        it 'cleans service cache' do
          Service.default_id('foo')
          expect(Memoizer.memoized?(Memoizer.build_key(Service, :default_id, 'foo'))).to be true

          service.save!
          expect(Memoizer.memoized?(Memoizer.build_key(Service, :default_id, 'foo'))).to be false
        end

        it 'validates user_registration_required field' do
          service.user_registration_required = false
          expect { service.save! }.to raise_error(ServiceRequiresDefaultUserPlan)
        end
      end

      describe '.delete_by_id' do
        let(:service){ Service.save! id: 7001, provider_key: 'foo' }

        it 'deletes a service' do
          Service.save! id: 7002, provider_key: 'foo', default_service: true
          Service.delete_by_id service.id

          expect(Service.load_by_id(service.id)).to be nil
          expect(Service.default_id(service.provider_key)).to eq '7002'
        end

        it 'raises an exception if you try to delete a default service' do
          expect { Service.delete_by_id(service.id) }.to raise_error(ServiceIsDefaultService)

          expect(Service.load_by_id(service.id)).not_to be nil
        end

        it 'raises an exception if you try to delete an invalid service' do
          invalid_id = service.id + 1
          expect { Service.delete_by_id(invalid_id) }.to raise_error(ServiceIdInvalid)

          expect(Service.load_by_id(invalid_id)).to be nil
        end
      end

    end
  end
end
