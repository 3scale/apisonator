# Test the extensions parsing as specified in RFC 0790
module ThreeScale
  module Backend
    describe Listener do
      describe '.threescale_extensions' do
        subject { described_class }

        let(:simple_key) { :a_value }
        let(:simple_val) { '1' }
        let(:simple) { URI.encode_www_form({ simple_key => simple_val }) }
        let(:simple_result) { { simple_key => simple_val } }

        let(:simple2_key) { :another_value }
        let(:simple2_val) { '2' }
        let(:simple2) { URI.encode_www_form(simple2_key => simple2_val) }

        let(:multiple) { "#{simple}&#{simple2}" }
        let(:multiple_result) { { simple_key => simple_val, simple2_key => simple2_val } }

        let(:array_key) { :array }
        let(:array_val) { ['1', '2'] }
        let(:array) { "#{array_key}[]=#{array_val[0]}&#{array_key}[]=#{array_val[1]}" }
        let(:array_result) { { array_key => array_val } }

        let(:hash_key) { :hash }
        let(:hash_keys) { [:key1, :key2 ] }
        let(:hash_vals) { ['1', '2'] }
        let(:hash) { "#{hash_key}[#{hash_keys[0]}]=#{hash_vals[0]}&" \
                     "#{hash_key}[#{hash_keys[1]}]=#{hash_vals[1]}" }
        let(:hash_result) {
          { hash_key => Hash[hash_keys.map(&:to_s).zip(hash_vals)] }
        }

        let(:combined) { multiple + '&' + array + '&' + hash }
        let(:combined_result) { multiple_result.merge(array_result.merge(hash_result)) }

        let(:spaces) { URI.encode_www_form('a key': ' a value') }
        let(:spaces_result) { { 'a key': ' a value' } }

        let(:special_characters_key) {
          :"key#{CGI.escape '&'}more#{CGI.escape '='}"
        }
        let(:special_characters_value) {
          :"a#{CGI.escape '&'}value#{CGI.escape '='}"
        }
        let(:special_characters) {
          URI.encode_www_form("#{special_characters_key}": "#{special_characters_value}")
        }
        let(:special_characters_result) {
          { "#{special_characters_key}": "#{special_characters_value}" }
        }

        shared_examples_for :parsing do |keytype|
          it "parses #{keytype.to_s.gsub('_', ' ')} parameters" do
            expect(subject.threescale_extensions(
              'HTTP_3SCALE_OPTIONS' => public_send(keytype)))
              .to eq(public_send("#{keytype}_result"))
          end
        end

        include_examples :parsing, :simple
        include_examples :parsing, :multiple
        include_examples :parsing, :array
        include_examples :parsing, :hash
        include_examples :parsing, :combined
        include_examples :parsing, :spaces
        include_examples :parsing, :special_characters
      end
    end
  end
end
