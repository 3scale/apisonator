require_relative '../../spec_helper'

module ThreeScale
  module Backend
    module OAuth
      describe Token do
        describe Token::Value do
          describe '.for' do
            it 'returns the app_id' do
              app_id = 'some_app_id'
              expect(described_class.for(app_id)).to eq app_id
            end
          end

          describe '.from' do
            it 'returns the app_id' do
              app_id = 'some_app_id'
              expect(described_class.from(app_id)).to eq app_id
            end
          end
        end
      end
    end
  end
end
