describe 'Internal API (prefix: /internal)' do

  before do
    header 'Accept', 'application/json'
    header 'Content-Type', 'application/json'
  end

  context 'GET /unknown/route/no/one/would/ever/try/to/use/in/a/real/app/omg' do
    it 'Check that unknown routes return proper 404' do
      get '/unknown/route/no/one/would/ever/try/to/use/in/a/real/app/omg'

      expect(status).to eq 404
      expect(response_json['status']).to eq 'not_found'
      expect(response_json['error']).to eq 'Not found'
    end
  end

  context 'GET /check.json' do
    it 'Check internal API live status' do
      get '/check.json'

      expect(status).to eq 200
      expect(response_json['status']).to eq 'ok'
    end
  end

  context 'GET /status' do
    it 'Get Backend\'s version' do
      get '/status'

      expect(status).to eq 200
      expect(response_json['status']).to eq 'ok'
      expect(response_json['version']['backend']).to eq ThreeScale::Backend::VERSION
    end
  end
end
