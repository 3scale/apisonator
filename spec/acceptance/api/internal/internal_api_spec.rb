resource 'Internal API (prefix: /internal)' do
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'

  get '/unknown/route/no/one/would/ever/try/to/use/in/a/real/app/omg' do
    example_request 'Check that unknown routes return proper 404' do
      expect(status).to eq 404
      expect(response_json['status']).to eq 'not_found'
      expect(response_json['error']).to eq 'Not found'
    end
  end

  get '/check.json' do
    example_request 'Check internal API live status' do
      expect(status).to eq 200
      expect(response_json['status']).to eq 'ok'
    end
  end

  get '/status' do
    example_request 'Get Backend\'s version' do
      expect(status).to eq 200
      expect(response_json['status']).to eq 'ok'
      expect(response_json['version']['backend']).to eq ThreeScale::Backend::VERSION
    end
  end
end
