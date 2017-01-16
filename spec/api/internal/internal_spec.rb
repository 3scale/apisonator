module ThreeScale
  module Backend
    module API
      describe Internal do
        describe '#credentials_set?' do
          let(:valid_username) { 'a_user' }
          let(:valid_password) { 'a_password' }
          let(:invalid_values) { [nil, ''] }

          context 'when both the user and password are set' do
            it 'returns true' do
              internal = Internal.new(username: valid_username,
                                      password: valid_password)
              expect(internal.helpers.credentials_set?).to be true
            end
          end

          context 'when only the user is set' do
            it 'returns true' do
              invalid_values.each do |invalid_password|
                internal = Internal.new(username: valid_username,
                                        password: invalid_password)
                expect(internal.helpers.credentials_set?).to be true
              end
            end
          end

          context 'when only the password is set' do
            it 'returns true' do
              invalid_values.each do |invalid_user|
                internal = Internal.new(username: invalid_user,
                                        password: valid_password)
                expect(internal.helpers.credentials_set?).to be true
              end
            end
          end

          context 'when neither the user nor the password are set' do
            it 'returns false' do
              invalid_values.product(invalid_values).each do |user, password|
                internal = Internal.new(username: user,
                                        password: password,
                                        allow_insecure: true)
                expect(internal.helpers.credentials_set?).to be false
              end
            end
          end
        end

        describe '#check_password' do
          let(:username) { 'a_user' }
          let(:password) { 'a_password' }
          let(:internal) { Internal.new(username: username, password: password) }

          context 'when both the user and the password match' do
            it 'returns true' do
              expect(internal.helpers.check_password(username, password)).to be true
            end
          end

          context 'when the user and password do not match' do
            let(:incorrect_user) { 'incorrect_user' }
            let(:incorrect_password) { 'incorrect_password' }
            let(:incorrect_combinations) do
              [[username, incorrect_password],
               [incorrect_user, password],
               [incorrect_user, incorrect_password]]
            end

            it 'returns false' do
              incorrect_combinations.each do |user, password|
                expect(internal.helpers.check_password(user, password)).to be false
              end
            end
          end
        end
      end
    end
  end
end
