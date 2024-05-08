module ThreeScale
  module Backend
    describe Service do

      # Note: in some tests, services are initialized with referrer_filters_required
      # set to false even when that field does not seem useful for what is
      # being tested. This field is set to false by default when the service is
      # saved. So it's just more convenient to set it as false when it's
      # instantiated so assertions are easier to write by allowing us to
      # compare the whole service object.

      service_id_invalid = ServiceIdInvalid
      provider_key_invalid = ProviderKeyInvalid
      pkey_invalid_or_service_missing = ProviderKeyInvalidOrServiceMissing

      describe '.default_id' do
        before { Service.storage.set('service/provider_key:foo/id', '7001') }

        it 'returns an ID' do
          expect(Service.default_id('foo')).to eq '7001'
        end
      end

      describe '.default_id!' do
        context 'when the provider exists' do
          let(:provider_key) { 'a_key' }
          let!(:service) { Service.save!(provider_key: provider_key, id: '1') }

          context 'and it has a default service' do
            it 'returns its ID' do
              expect(Service.default_id!(provider_key)).to eq service.id
            end
          end

          context 'and it does not have a default service' do
            before do
              service.delete_data
              service.clear_cache
            end

            it "raises #{provider_key_invalid}" do
              expect { Service.default_id!(provider_key_invalid) }
                  .to raise_error provider_key_invalid
            end
          end
        end

        context 'when the provider does not exist' do
          it "raises #{provider_key_invalid}" do
            expect { Service.default_id!('a_key') }
                .to raise_error provider_key_invalid
          end
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
      end

      describe '.load_with_provider_key!' do
        context 'when a service ID is not specified' do
          let(:provider_key) { 'a_provider_key' }

          context 'and the provider key has a default service associated' do
            let(:default_service_id) { '123' }
            let(:other_service_id) { '456' }

            let!(:default_service) do
              Service.save!(provider_key: provider_key,
                            id: default_service_id,
                            referrer_filters_required: false)
            end

            let!(:other_service) do
              Service.save!(provider_key: provider_key,
                            id: other_service_id,
                            referrer_filters_required: false)
            end

            it 'returns the default service' do
              expect(Service.load_with_provider_key!(nil, provider_key).to_hash)
                  .to eq default_service.to_hash
            end
          end

          context 'and the provider key does not have a default service associated' do
            it "raises #{pkey_invalid_or_service_missing}" do
              expect { Service.load_with_provider_key!(nil, provider_key) }
                  .to raise_error pkey_invalid_or_service_missing
            end
          end
        end

        context 'when a service ID is specified' do
          context 'and it does not exist' do
            it "raises #{service_id_invalid}" do
              expect { Service.load_with_provider_key!('non_existing_service_id', 'a_key') }
                  .to raise_error service_id_invalid
            end
          end

          context 'and it exists' do
            context 'and it belongs to the provider key' do
              let(:provider_key) { 'a_key' }
              let!(:service) do
                Service.save!(provider_key: provider_key,
                              id: '123',
                              referrer_filters_required: false)
              end

              it 'returns the service' do
                expect(Service.load_with_provider_key!(service.id, provider_key).to_hash)
                    .to eq service.to_hash
              end
            end

            context 'and it does not belong to the provider key' do
              context 'and the provider key exists and has a default service' do
                let(:provider_key_1) { 'a_key_1' }
                let(:provider_key_2) { 'a_key_2' }
                let!(:service_pkey1) do
                  Service.save!(provider_key: provider_key_1,
                                id: '123',
                                referrer_filters_required: false)
                end
                let!(:service_pkey2) do
                  Service.save!(provider_key: provider_key_2,
                                id: '456',
                                referrer_filters_required: false)
                end

                it "raises #{service_id_invalid}" do
                  expect { Service.load_with_provider_key!(service_pkey2.id, provider_key_1) }
                      .to raise_error service_id_invalid
                end
              end

              context 'and the provider key exists but does not have a default service' do
                let(:provider_key_1) { 'a_key_1' }
                let(:provider_key_2) { 'a_key_2' }
                let!(:service_pkey1) do
                  Service.save!(provider_key: provider_key_1,
                                id: '123',
                                referrer_filters_required: false)
                end
                let!(:service_pkey2) do
                  Service.save!(provider_key: provider_key_2,
                                id: '456',
                                referrer_filters_required: false)
                end

                before do
                  # Delete service so the provider key does not have a default one
                  Service.load_by_id(service_pkey1.id).tap do |service|
                    service.delete_data
                    service.clear_cache
                  end
                end

                it "raises #{provider_key_invalid}" do
                  expect { Service.load_with_provider_key!(service_pkey2.id, provider_key_1) }
                      .to raise_error provider_key_invalid
                end
              end

              context 'because the provider key does not exist' do
                let(:provider_key) { 'a_key' }
                let(:service_pkey) { 'another_key' }
                let!(:service) do
                  Service.save!(provider_key: service_pkey,
                                id: '123',
                                referrer_filters_required: false)
                end

                it "raises #{provider_key_invalid}" do
                  expect { Service.load_with_provider_key!(service.id, provider_key) }
                      .to raise_error provider_key_invalid
                end
              end
            end
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
      end

      describe '.delete_by_id' do
        let(:service){ Service.save! id: 7001, provider_key: 'foo' }

        it 'deletes a service' do
          Service.save! id: 7002, provider_key: 'foo', default_service: true
          Service.delete_by_id service.id

          expect(Service.load_by_id(service.id)).to be nil
          expect(Service.default_id(service.provider_key)).to eq '7002'
        end

        it 'deletes all service errors' do
          Service.save! id: 7002, provider_key: 'foo', default_service: true
          ErrorStorage.store(service.id, ApplicationNotFound.new('foo'))
          ErrorStorage.store(service.id, ApplicationNotFound.new('foo2'))

          expect { Service.delete_by_id(service.id) }
            .to change { ErrorStorage.count(service.id) }.from(2).to(0)
        end

        it 'does not raise an exception when deleting a service without errors or latest transactions' do
          Service.save! id: 7002, provider_key: 'foo', default_service: true
          expect { Service.delete_by_id(service.id) }.to_not raise_error
        end

        it 'deletes a service when it is the only one for the provider' do
          Service.delete_by_id service.id

          expect(Service.load_by_id(service.id)).to be nil
        end

        it 'raises an exception when deleting a default service and there are others' do
          Service.save! id: 7002, provider_key: 'foo', default_service: false

          expect { Service.delete_by_id(service.id) }.to raise_error(ServiceIsDefaultService)

          expect(Service.load_by_id(service.id)).not_to be nil
        end

        it 'raises an exception if you try to delete an invalid service' do
          invalid_id = service.id + 1
          expect { Service.delete_by_id(invalid_id) }.to raise_error(ServiceIdInvalid)

          expect(Service.load_by_id(invalid_id)).to be nil
        end
      end

      describe '.provider_key_for' do
        context 'when the service exists' do
          let(:provider_key) { 'abc' }
          let(:service_id) { 123 }

          before { Service.save!(id: service_id, provider_key: provider_key) }

          it 'returns its provider key' do
            expect(Service.provider_key_for(service_id)).to eq provider_key
          end
        end

        context 'when the service does not exist' do
          let(:non_existing_service_id) { 321 }

          it 'returns nil' do
            expect(Service.provider_key_for(non_existing_service_id)).to be nil
          end
        end
      end

      describe '.active?' do
        it 'returns true when service is active' do
          [
            { state: :active, id: '8001', provider_key: 'foo' },
            { state: 'active', id: '8001', provider_key: 'foo' },
            # even when state is not set
            { id: '8001', provider_key: 'foo' },
            # even when state is intentionally set as nil
            { state: nil, id: '9001', provider_key: 'foo'}
          ].each do |svc_attrs|
            expect(Service.save!(svc_attrs).active?).to be_truthy
          end
        end

        it 'returns false when the service is disabled' do
          [
            { state: :suspended, id: '9001', provider_key: 'foo' },
            { state: 'suspended', id: '9001', provider_key: 'foo' },
            { state: :something, id: '9001', provider_key: 'foo' },
            { state: :disable, id: '9001', provider_key: 'foo' },
            { state: :disabled, id: '9001', provider_key: 'foo' },
            { state: '1', id: '9001', provider_key: 'foo' },
            { state: '0', id: '9001', provider_key: 'foo' },
            { state: 'true', id: '9001', provider_key: 'foo' },
            { state: 'false', id: '9001', provider_key: 'foo' }
          ].each do |svc_attrs|
            expect(Service.save!(svc_attrs).active?).to be_falsy
          end
        end

        it 'returns true when the service does not have state in the DB' do
          service_id = '9001'
          Service.save!({state: :suspended, id: service_id, provider_key: 'foo', default_service: false})
          Service.storage.del ThreeScale::Backend::Service.storage_key(service_id, 'state')
          expect(Service.load_by_id(service_id).active?).to be true
          Service.delete_by_id(service_id)
        end

        it 'returns false when the service has an invalid state in the DB' do
          service_id = '9001'
          Service.save!({state: :not_defined_state, id: service_id, provider_key: 'foo', default_service: false})
          Service.storage.set ThreeScale::Backend::Service.storage_key(service_id, 'state'), 'not_defined_state'
          expect(Service.load_by_id(service_id).active?).to be false
          Service.delete_by_id(service_id)
        end
      end

      describe '#active=' do
        it 'when set to true, active? returns true' do
          [
            { state: :suspended, id: '9001', provider_key: 'foo', default_service: false },
            { state: :active, id: '9001', provider_key: 'foo', default_service: false },
            { state: :something, id: '9001', provider_key: 'foo', default_service: false },
            { state: nil, id: '9001', provider_key: 'foo', default_service: false },
            { state: "", id: '9001', provider_key: 'foo', default_service: false },
            { id: '9001', provider_key: 'foo', default_service: false}
          ].each do |svc_attrs|
            service = Service.save!(svc_attrs)
            service.active = true
            expect(service.active?).to be true
            Service.delete_by_id('9001')
          end
        end

        it 'when set to false, active? returns false' do
          [
            { state: :suspended, id: '9001', provider_key: 'foo', default_service: false },
            { state: :active, id: '9001', provider_key: 'foo', default_service: false },
            { state: :something, id: '9001', provider_key: 'foo', default_service: false },
            { state: nil, id: '9001', provider_key: 'foo', default_service: false },
            { state: "", id: '9001', provider_key: 'foo', default_service: false },
            { id: '9001', provider_key: 'foo', default_service: false}
          ].each do |svc_attrs|
            service = Service.save!(svc_attrs)
            service.active = false
            expect(service.active?).to be false
            Service.delete_by_id('9001')
          end
        end
      end
    end
  end
end
