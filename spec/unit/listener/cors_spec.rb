module ThreeScale
  module Backend
    describe CORS do
      subject { described_class }

      # requires let(:hash)
      shared_examples_for 'hash of strings to strings' do
        it 'is a hash' do
          expect(hash).to be_a(Hash)
        end

        it "keys is a set of strings" do
          expect(hash.keys).to all(be_instance_of String)
        end

        it "values is a set of strings" do
          expect(hash.values).to all(be_instance_of String)
        end
      end

      # requires let(:hash)
      shared_examples_for 'contains header' do |header, value=nil|
        it "contains header #{header}" do
          expect(hash.keys).to include(header)
        end

        unless value.nil?
          it "contains header #{header} with value #{value}" do
            expect(hash.fetch(header)).to eq(value)
          end
        end
      end

      describe '.headers' do
        let(:hash) { subject.headers }

        it_behaves_like 'hash of strings to strings'

        include_examples 'contains header',
          'Access-Control-Allow-Origin', described_class.const_get(:ALLOW_ORIGIN)
        include_examples 'contains header',
          'Access-Control-Expose-Headers', described_class.const_get(:EXPOSE_HEADERS_S)
      end

      describe '.options_headers' do
        let(:hash) { subject.options_headers }

        it_behaves_like 'hash of strings to strings'

        include_examples 'contains header',
          'Access-Control-Allow-Origin', described_class.const_get(:ALLOW_ORIGIN)
        include_examples 'contains header',
          'Access-Control-Expose-Headers', described_class.const_get(:EXPOSE_HEADERS_S)
        include_examples 'contains header',
          'Access-Control-Max-Age', described_class.const_get(:MAX_AGE_S)
        include_examples 'contains header',
          'Access-Control-Allow-Methods', described_class.const_get(:ALLOW_METHODS_S)
        include_examples 'contains header',
          'Access-Control-Allow-Headers', described_class.const_get(:ALLOW_HEADERS_S)
      end
    end
  end
end
