require_relative '../../spec_helper'

module ThreeScale
  module Backend
    module Stats
      module Keys
        module Generator
          describe Partition do
            it 'instantiates correctly' do
              # TODO fix input introducing a real key generator
              # and not a simple array, to make the test more
              # real
              expect { Partition.new([1,2]) }.to_not raise_error
            end

            it 'does not crash when executing #each' do
              partition = Partition.new([1,2])
              expect { partition.each { nil } }.to_not raise_error
            end
          end
        end
      end
    end
  end
end