require_relative '../../acceptance_spec_helper'

resource 'Users (prefix: /services/:service_id/users)' do
  set_app ThreeScale::Backend::API::Internal
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
      status.should == 200
      response_json['user']['username'].should == username
      response_json['user']['service_id'].should == service_id
      response_json['user']['state'].should == state.to_s
      response_json['user']['plan_id'].should == plan_id
      response_json['user']['plan_name'].should == plan_name
    end

    example 'Try to get a User by non-existent username' do
      do_request username: username_non_existent
      [400, 404].should include(status)
      response_json['error'].should =~ /not found/i
    end

    example 'Try to get a User by non-existent service ID' do
      do_request service_id: service_id_non_existent
      [400, 404].should include(status)
      response_json['error'].should =~ /not found/i
    end
  end

  post '/services/:service_id/users/:username' do
    parameter :service_id, 'Service ID', required: true
    parameter :username, 'User name', required: true
    parameter :user, 'User attributes', required: true

    let(:raw_post) { params.to_json }

    example_request 'Create a User' do
      status.should == 201
      response_json['status'].should == 'created'

      (user = ThreeScale::Backend::User.load(service_id, username)).should_not be_nil
      user.username.should == username
      user.service_id.should == service_id
      user.state.should == state
      user.plan_id.should == plan_id
      user.plan_name.should == plan_name
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
      status.should == 200
      response_json['status'].should == 'modified'

      (user = ThreeScale::Backend::User.load(service_id, username)).should_not be_nil
      user.username.should == username
      user.service_id.should == service_id
      user.state.should == state
      user.plan_id.should == plan_id
      user.plan_name.should == modified_plan_name
    end
  end

  delete '/services/:service_id/users/:username' do
    parameter :service_id, 'Service ID', required: true
    parameter :username, 'User name', required: true

    example_request 'Deleting a User' do
      status.should == 200
      response_json['status'].should == 'deleted'
      ThreeScale::Backend::User.load(service_id, username).should be_nil
    end
  end

end
