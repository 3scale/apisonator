require_relative '../../acceptance_spec_helper'

resource 'Service Tokens (prefix: /service_tokens)' do
  set_app ThreeScale::Backend::API::Internal
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'

  # This is just so we check the messages just once and use constants from there
  before(:all) do
    expect(ThreeScale::Backend::ServiceToken::InvalidServiceToken.new.message)
        .to eq 'Service token cannot be blank'
    expect(ThreeScale::Backend::ServiceToken::InvalidServiceId.new.message)
        .to eq 'Service ID cannot be blank'
  end

  post '/service_tokens/' do
    parameter :service_tokens, 'Service Tokens', required: true

    let(:service_token) { 'a_token' }
    let(:service_id) { 'a_service_id' }

    let(:service_tokens) do
      { service_token => { service_id: service_id },
        service_token.succ => { service_id: service_id } }
    end

    let(:invalid_service_token_error) do
      ThreeScale::Backend::ServiceToken::InvalidServiceToken
    end

    let(:invalid_service_id_error) do
      ThreeScale::Backend::ServiceToken::InvalidServiceId
    end

    let(:raw_post) { params.to_json }

    example_request 'Create a (service_token, service_id) pair' do
      expect(status).to eq 201
      expect(response_json['status']).to eq 'created'

      service_tokens.each do |token, token_info|
        expect(ThreeScale::Backend::ServiceToken.exists?(token, token_info[:service_id]))
            .to be true
      end
    end

    example 'Try to create a (service_token, service_id) pair with null service_token' do
      do_request(service_tokens: { nil => { service_id: service_id } })

      expect(status).to eq invalid_service_token_error.new.http_code
      expect(response_json['error']).to eq invalid_service_token_error.new.message
    end

    example 'Try to create a (service_token, service_id) pair with empty service_token' do
      do_request(service_tokens: { '' => { service_id: service_id } })

      expect(status).to eq invalid_service_token_error.new.http_code
      expect(response_json['error']).to eq invalid_service_token_error.new.message
    end

    example 'Try to create a (service_token, service_id) pair with null service_id' do
      do_request(service_tokens: { service_token => { service_id: nil } })

      expect(status).to eq invalid_service_id_error.new.http_code
      expect(response_json['error']).to eq invalid_service_id_error.new.message
    end

    example 'Try to create a (service_token, service_id) pair with empty service_id' do
      do_request(service_tokens: { service_token => { service_id: '' } })

      expect(status).to eq invalid_service_id_error.new.http_code
      expect(response_json['error']).to eq invalid_service_id_error.new.message
    end

    example 'Try to create a (service_token, service_id) without sending service_tokens' do
      do_request(service_tokens: nil)

      expect(status).to eq 400
      expect(response_json['error']).to eq "missing parameter 'service_tokens'"
    end

    example 'Try to create (service_token, service_id) pairs including one with invalid ID' do
      tokens = service_tokens.merge({ 'valid_token' => { service_id: '' } })
      do_request(service_tokens: tokens)

      expect(status).to eq invalid_service_id_error.new.http_code
      expect(response_json['error']).to eq invalid_service_id_error.new.message

      tokens.each do |token, token_info|
        expect(ThreeScale::Backend::ServiceToken.exists?(token, token_info[:service_id]))
            .to be false
      end
    end

    example 'Try to create (service_token, service_id) pairs including one with invalid token' do
      tokens = service_tokens.merge({ '' => { service_id: service_id } })
      do_request(service_tokens: tokens)

      expect(status).to eq invalid_service_token_error.new.http_code
      expect(response_json['error']).to eq invalid_service_token_error.new.message

      tokens.each do |token, token_info|
        expect(ThreeScale::Backend::ServiceToken.exists?(token, token_info[:service_id]))
            .to be false
      end
    end
  end

  delete '/service_tokens/' do
    parameter :service_tokens, 'Service token', required: true

    let(:existing_tokens) do
      [{ service_token: 'token1', service_id: 'id1' },
       { service_token: 'token2', service_id: 'id2' }]
    end

    let(:non_existing_tokens) do
      [{ service_token: 'token3', service_id: 'id3' }]
    end

    let(:service_tokens) { existing_tokens + non_existing_tokens }
    let(:raw_post) { params.to_json }

    before do
      existing_tokens.each do |token|
        ThreeScale::Backend::ServiceToken.save(token[:service_token], token[:service_id])
      end
    end

    example_request 'Delete a list of (service_token, service_id) pairs' do
      expect(status).to eq 200
      expect(response_json['status']).to eq 'deleted'
      expect(response_json['count']).to eq existing_tokens.size

      existing_tokens.each do |token|
        expect(ThreeScale::Backend::ServiceToken.exists?(
            token[:service_token], token[:service_id])).to be false
      end
    end

    example 'Try to delete list of (service_token, service_id) without sending service_tokens' do
      do_request(service_tokens: nil)

      expect(status).to eq 400
      expect(response_json['error']).to eq "missing parameter 'service_tokens'"
    end

    example 'Try to delete a list of (service_token, service_id) that does not exist' do
      do_request(service_tokens: non_existing_tokens)

      expect(status).to eq 200
      expect(response_json['status']).to eq 'deleted'
      expect(response_json['count']).to be_zero
    end
  end
end
