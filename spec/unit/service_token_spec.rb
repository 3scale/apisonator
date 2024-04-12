module ThreeScale
  module Backend
    describe ServiceToken do
      invalid_service_token_exc = described_class::InvalidServiceToken.to_s.split(':').last
      invalid_service_id_exc = described_class::InvalidServiceId.to_s.split(':').last

      subject { ServiceToken }

      let(:invalid_service_token_error) { subject::InvalidServiceToken }
      let(:invalid_service_id_error) { subject::InvalidServiceId }
      let(:service_token) { 'a_service_token' }
      let(:service_id) { 'a_service_id' }

      before { subject.delete(service_token, service_id) }

      describe '.save' do
        context 'when both service_token and service_id are not nil and not empty' do
          it 'saves the (service_token, service_id) pair' do
            subject.save(service_token, service_id)
            expect(subject.exists?(service_token, service_id)).to be true
          end
        end

        context 'when service_token is invalid' do
          ['', nil].each do |invalid_service_token|
            context "because it is #{invalid_service_token.inspect}" do
              it "raises #{invalid_service_token_exc}" do
                expect { subject.save(invalid_service_token, service_id) }
                    .to raise_error invalid_service_token_error
              end
            end
          end
        end

        context 'when service_id is invalid' do
          ['', nil].each do |invalid_service_id|
            context "because it is #{invalid_service_id.inspect}" do
              it "raises #{invalid_service_id_exc}" do
                expect { subject.save(service_token, invalid_service_id) }
                    .to raise_error invalid_service_id_error
              end
            end
          end
        end

        context 'when service_id is an integer and service_token is valid' do
          let(:service_id) { 123 }

          it 'saves the (service_token, service_id) pair' do
            subject.save(service_token, service_id)
            expect(subject.exists?(service_token, service_id)).to be true
          end
        end
      end

      describe '.save_pairs' do
        let(:service_tokens) do
          [{ service_token: 't1', service_id: 'i1' },
           { service_token: 't2', service_id: 'i2' }]
        end

        context 'when all the pairs are valid' do
          it 'saves all the pairs' do
            subject.save_pairs(service_tokens)
            service_tokens.each do |token|
              expect(subject.exists?(token[:service_token], token[:service_id])).to be true
            end
          end
        end

        context 'when one of the pairs contains a an invalid service_token' do
          ['', nil].each do |invalid_service_token|
            context "because it is #{invalid_service_token.inspect}" do
              let(:tokens) do
                service_tokens.push({ service_token: invalid_service_token,
                                      service_id: 'id' })
              end

              it "raises #{invalid_service_token_exc}" do
                expect { subject.save_pairs(tokens) }
                    .to raise_error invalid_service_token_error
              end

              it 'does not save any pairs' do
                service_tokens.each do |token|
                  expect(subject.exists?(token[:service_token], token[:service_id])).to be false
                end
              end
            end
          end
        end

        context 'when one of the pairs contains an invalid service_id' do
          ['', nil].each do |invalid_service_id|
            context "because it is #{invalid_service_id.inspect}" do
              let(:tokens) do
                service_tokens.push({ service_token: 'token',
                                      service_id: invalid_service_id })
              end

              it "raises #{invalid_service_id_exc}" do
                expect { subject.save_pairs(tokens) }
                    .to raise_error invalid_service_id_error
              end

              it 'does not save any pairs' do
                service_tokens.each do |token|
                  expect(subject.exists?(token[:service_token], token[:service_id])).to be false
                end
              end
            end
          end
        end

        context 'when several pairs have invalid service tokens or IDs' do
          let(:invalid_service_id) { '' }
          let(:invalid_service_token) { nil }

          let(:tokens) do
            service_tokens.push(
                { service_token: 'valid_token', service_id: invalid_service_id },
                { service_token: invalid_service_token, service_id: 'valid_id' })
          end

          it "raises #{invalid_service_token_exc}" do
            expect { subject.save_pairs(tokens) }
                .to raise_error invalid_service_token_error
          end

          it 'does not save any pairs' do
            service_tokens.each do |token|
              expect(subject.exists?(token[:service_token], token[:service_id])).to be false
            end
          end
        end
      end

      describe '.delete' do
        context 'when the (service_token, service_id) pair exists' do
          before { subject.save(service_token, service_id) }

          it 'deletes the (service_token, service_id) pair' do
            subject.delete(service_token, service_id)
            expect(subject.exists?(service_token, service_id)).to be false
          end

          it 'returns 1' do
            expect(subject.delete(service_token, service_id)).to eq 1
          end
        end

        context 'when the (service_token, service_id) pair does not exists' do
          it 'returns 0' do
            expect(subject.delete(service_token, service_id)).to be_zero
          end
        end
      end

      describe '.exists?' do
        context 'when the (service_token, service_id) pair exists' do
          before { subject.save(service_token, service_id) }

          it 'returns true' do
            expect(subject.exists?(service_token, service_id)).to be true
          end
        end

        context 'when the (service_token, service_id) pair does not exist' do
          it 'returns false' do
            expect(subject.exists?(service_token, service_id)).to be false
          end
        end
      end
    end
  end
end
