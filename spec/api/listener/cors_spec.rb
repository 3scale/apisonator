require 'rack/test'

module ThreeScale
  module Backend
    describe CORS do
      include ::Rack::Test::Methods

      REQUIRED_ENDPOINT_HEADERS = [
        'Access-Control-Allow-Origin',
        'Access-Control-Expose-Headers',
      ]
      REQUIRED_OPTIONS_HEADERS = REQUIRED_ENDPOINT_HEADERS + [
        'Access-Control-Allow-Methods',
        'Access-Control-Allow-Headers',
      ]

      let(:app) { Listener.new }

      shared_examples_for 'contains header' do |h, v=nil|
        it "returns header #{h}" do
          expect(last_response.headers.keys).to include(h)
        end

        unless v.nil?
          it "returns #{h} header with #{v} value" do
            expect(last_response.headers[h]).to eq(v)
          end
        end
      end

      ENDPOINTS = [
        '/',
        '/transactions/authorize.xml',
        '/non/existent/endpoint',
      ]

      [
        :OPTIONS,
        :GET,
        :POST,
      ].product(ENDPOINTS).each do |verb, endpoint|
        context "when calling #{verb} on #{endpoint}"  do
          before do
            send verb.downcase, endpoint
          end

          if verb == 'OPTIONS'
            it "returns 204" do
              expect(last_response.status).to eq 204
            end

            required_headers = REQUIRED_OPTIONS_HEADERS
            headers = :OPTIONS_HEADERS
          else
            required_headers = REQUIRED_ENDPOINT_HEADERS
            headers = :HEADERS
          end

          required_headers.each do |h|
            include_examples 'contains header', h
          end

          described_class.const_get(headers).each do |h, v|
            include_examples 'contains header', h, v
          end
        end
      end
    end
  end
end
