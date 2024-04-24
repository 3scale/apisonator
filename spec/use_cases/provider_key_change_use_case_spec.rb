module ThreeScale
  module Backend
    describe ProviderKeyChangeUseCase do
      describe '#initialize' do
        errors = { invalid_provider_keys: InvalidProviderKeys,
                   provider_key_exists: ProviderKeyExists,
                   provider_key_not_found: ProviderKeyNotFound }

        invalid_keys = [nil, '']

        let(:a_provider_key) { '123' }

        context 'when the provider keys are invalid' do
          it "raises #{formatted_name(errors[:invalid_provider_keys])}" do
            expect { ProviderKeyChangeUseCase.new(a_provider_key, a_provider_key) }
                .to raise_error(errors[:invalid_provider_keys])
          end
        end

        context 'when the old provider key is invalid' do
          invalid_keys.each do |invalid_key|
            context "because it is #{invalid_key.inspect}" do
              it "raises #{formatted_name(errors[:invalid_provider_keys])}" do
                expect { ProviderKeyChangeUseCase.new(invalid_key, a_provider_key) }
                    .to raise_error(errors[:invalid_provider_keys])
              end
            end
          end
        end

        context 'when the new provider key is invalid' do
          invalid_keys.each do |invalid_key|
            context "because it is #{invalid_key.inspect}" do
              it "raises #{formatted_name(errors[:invalid_provider_keys])}" do
                expect { ProviderKeyChangeUseCase.new(a_provider_key, invalid_key) }
                    .to raise_error(errors[:invalid_provider_keys])
              end
            end
          end
        end

        context 'when the new provider key already exists' do
          let(:existing_key) { 'existing' }

          before { Service.save! id: 7003, provider_key: existing_key }

          it "raises #{formatted_name(errors[:provider_key_exists])}" do
            expect { ProviderKeyChangeUseCase.new(a_provider_key, existing_key) }
                .to raise_error(errors[:provider_key_exists])
          end
        end

        context 'when the old provider key does not exist' do
          let(:non_existing_key) { 'non_existing' }

          it "raises #{formatted_name(errors[:provider_key_not_found])}" do
            expect { ProviderKeyChangeUseCase.new(non_existing_key, a_provider_key) }
                .to raise_error(errors[:provider_key_not_found])
          end
        end
      end

      describe '#process' do
        let(:old_key) { 'foo' }
        let(:new_key) { 'bar' }
        let(:service_ids_with_old_key) { [7001, 7002] }
        let(:use_case) { ProviderKeyChangeUseCase.new(old_key, new_key) }

        def exercise_provider_service_memoizer(provider_key, service_id)
          # Call the Service class methods just to force the memoization
          # of them with specific values
          Service.default_id(provider_key)
          Service.authenticate_service_id(service_id, provider_key)
          Service.load_by_id(service_id)
          Service.list(provider_key)
          Service.provider_key_for(service_id)
        end

        def build_provider_service_memoizer_keys(provider_key, service_id)
          Memoizer.build_keys_for_class(Service,
            authenticate_service_id: [service_id, provider_key],
            default_id: [provider_key],
            load_by_id: [service_id],
            list: [provider_key],
            provider_key_for: [service_id])
        end

        before do
          service_ids_with_old_key.each do |service_id|
            Service.save! id: service_id, provider_key: old_key
          end
        end

        it 'changes the provider key of existing services' do
          use_case.process
          expect(Service.list(new_key))
              .to eq service_ids_with_old_key.map(&:to_s)

          service_ids_with_old_key.each do |service_id|
            expect(Service.load_by_id(service_id).provider_key).to eq new_key
          end
        end

        it 'sets the default service for the new provider key' do
          use_case.process
          expect(Service.default_id(new_key))
              .to eq service_ids_with_old_key.first.to_s
        end

        it 'removes (old) provider key data' do
          use_case.process
          expect(Service.default_id(old_key)).to be nil
          expect(Service.list(old_key)).to be_empty
        end

        it 'changes the provider key associated with the affected services' do
          use_case.process
          service_ids_with_old_key.each do |service_id|
            expect(Service.provider_key_for(service_id)).to eq new_key
          end
        end

        it 'clears the Service cache keys of the old provider key' do
          service_ids_with_old_key.each do |service_id|
            exercise_provider_service_memoizer(old_key, service_id)
            memoizer_keys = build_provider_service_memoizer_keys(old_key, service_id)

            expect { use_case.process }
            .to change { memoizer_keys.count { |k| Memoizer.memoized?(k) } }
            .from(memoizer_keys.size)
            .to(0)
          end
        end

        it 'clears the Service cache keys of the new provider key' do
          service_ids_with_old_key.each do |service_id|
            exercise_provider_service_memoizer(new_key, service_id)
            memoizer_keys = build_provider_service_memoizer_keys(new_key, service_id)

            expect { use_case.process }
            .to change { memoizer_keys.count { |k| Memoizer.memoized?(k) } }
            .from(memoizer_keys.size)
            .to(0)
          end
        end
      end
    end
  end
end
