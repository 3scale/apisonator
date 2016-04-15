require_relative '../../spec_helper'

module ThreeScale
  module Backend
    module OAuth
      describe Token do
        # static parameters, not important here
        service_id = '1001'
        ttl = -1

        # variable parameters
        tokens = [
          'SomEoAuTHtok3n',
          'va/lid/tok/en'
        ]
        app_ids = [
          '2001',
          'user_len:5/myapp'
        ]
        user_ids = ['alex', 'user_len:1/x', 'user_len:200/uid', nil]

        # build combinations of parameters
        constructors_w_params = tokens.product(app_ids, user_ids)
          .inject({}) do |acc, (token, app_id, user_id)|
            acc[:new] ||= []
            acc[:new] << [
              Token.new(token, service_id, app_id, user_id, ttl),
              token, app_id, user_id
            ]
            acc
          end
        # Add another constructor JUST to spec .from_value, because all
        # parameter combinations have been added already for .new. We do not
        # need to retest those with .from_value, just one and see if it works.
        constructors_w_params[:from_value] = [[
          Token.from_value(tokens.first, service_id, Token::Value.for(app_ids.first, user_ids.first), ttl),
          tokens.first, app_ids.first, user_ids.first
        ]]
        constructors_w_params.each do |constructor, subject_params|
          subject_params.each do |subject, token, app_id, user_id|
            describe ".#{constructor}" do
              context "with token #{token.inspect}, app_id #{app_id.inspect}, " \
                "user_id #{user_id.inspect}" do
                [:token, :service_id, :app_id, :user_id, :ttl].each do |attr|
                  let(attr) { binding.local_variable_get attr }
                  describe "##{attr}" do
                    it "returns the associated #{attr}" do
                      expect(subject.public_send attr).to eq(public_send attr)
                    end
                  end
                end

                describe '#key' do
                  it 'provides the key used for storage' do
                    expect(subject.key).to eq(Token::Key.for token, service_id)
                  end
                end

                describe '#value' do
                  it "returns the stored value for the associated app and " \
                    "user id #{user_id.inspect}" do
                    expect(subject.value).to eq(Token::Value.for app_id, user_id)
                  end
                end
              end
            end
          end
        end

        describe Token::Value do
          app_ids.product(user_ids) do |app_id, user_id|
            describe '.for' do
              it "provides an encoded string out of an app_id #{app_id.inspect} " \
                 "and user_id #{user_id.inspect}" do
                expect(described_class.for(app_id, user_id)).to be_a(String)
              end
            end

            describe '.from' do
              it "returns the app_id #{app_id.inspect} and user_id " \
                 "#{user_id.inspect} out of an encoded string" do
                expect(described_class.from(described_class.for(app_id, user_id))).
                  to eq([app_id, user_id])
              end
            end
          end
        end
      end
    end
  end
end
