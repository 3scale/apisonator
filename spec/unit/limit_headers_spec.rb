module ThreeScale
  module Backend
    module Transactor
      describe LimitHeaders do
        describe '.get' do
          context 'when no reports received' do
            it 'returns nil' do
              expect(described_class.get([])).to be_nil
            end
          end
        end
      end
    end
  end
end
