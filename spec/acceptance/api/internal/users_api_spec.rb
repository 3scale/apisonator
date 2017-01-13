require_relative '../../acceptance_spec_helper'

resource 'Users (prefix: /services/:service_id/users)' do
  set_app(ThreeScale::Backend::API::Internal.new(allow_insecure: true))
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'

  let(:service_id) { '7575' }
  let(:username) { 'pancho' }
  let(:state) { :active }
  let(:plan_id) { '80210' }
  let(:plan_name) { 'foobar' }
  let(:service_id_non_existent) { service_id.to_i.succ.to_s }
  let(:username_non_existent) { username + '_nonexistent' }
  let(:user) do
    {
      service_id: service_id,
      username: username,
      state: state,
      plan_id: plan_id,
      plan_name: plan_name
    }
  end

  before do
    ThreeScale::Backend::Service.save!(id: service_id, provider_key: 'a_provider')

    ThreeScale::Backend::User.delete!(service_id, username) rescue nil
    ThreeScale::Backend::User.delete!(service_id, username_non_existent) rescue nil
    ThreeScale::Backend::User.save!(service_id: service_id,
                                    username: username,
                                    state: state,
                                    plan_id: plan_id,
                                    plan_name: plan_name)
  end

  get '/services/:service_id/users/:username' do
    parameter :service_id, 'Service ID', required: true
    parameter :username, 'User name', required: true

    example_request 'Get User' do
      expect(status).to eq 200
      expect(response_json['user']['username']).to eq username
      expect(response_json['user']['service_id']).to eq service_id
      expect(response_json['user']['state']).to eq state.to_s
      expect(response_json['user']['plan_id']).to eq plan_id
      expect(response_json['user']['plan_name']).to eq plan_name
    end

    example 'Try to get a User by non-existent username' do
      do_request username: username_non_existent
      expect([400, 404]).to include status
      expect(response_json['error']).to match /not found/i
    end

    example 'Try to get a User by non-existent service ID' do
      do_request service_id: service_id_non_existent
      expect([400, 404]).to include status
      expect(response_json['error']).to match /not found/i
    end
  end

  post '/services/:service_id/users/:username' do
    parameter :service_id, 'Service ID', required: true
    parameter :username, 'User name', required: true
    parameter :user, 'User attributes', required: true

    let(:raw_post) { params.to_json }

    example_request 'Create a User' do
      expect(status).to eq 201
      expect(response_json['status']).to eq 'created'

      user = ThreeScale::Backend::User.load(service_id, username)
      expect(user.username).to eq username
      expect(user.service_id).to eq service_id
      expect(user.state).to eq state
      expect(user.plan_id).to eq plan_id
      expect(user.plan_name).to eq plan_name
    end
  end

  put '/services/:service_id/users/:username' do
    parameter :service_id, 'Service ID', required: true
    parameter :username, 'User name', required: true
    parameter :user, 'User attributes', required: true

    let(:modified_plan_name) { plan_name + '_modified' }
    let(:modified_user) { user.merge(plan_name: modified_plan_name) }

    let(:raw_post) { params.to_json }

    example 'Update User' do
      do_request user: modified_user
      expect(status).to eq 200
      expect(response_json['status']).to eq 'modified'

      user = ThreeScale::Backend::User.load(service_id, username)
      expect(user.username).to eq username
      expect(user.service_id).to eq service_id
      expect(user.state).to eq state
      expect(user.plan_id).to eq plan_id
      expect(user.plan_name).to eq modified_plan_name
    end
  end

  delete '/services/:service_id/users/:username' do
    parameter :service_id, 'Service ID', required: true
    parameter :username, 'User name', required: true

    example_request 'Deleting a User' do
      expect(status).to eq 200
      expect(response_json['status']).to eq 'deleted'
      expect(ThreeScale::Backend::User.load(service_id, username)).to be nil
    end
  end

end
