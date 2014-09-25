require_relative '../../acceptance_spec_helper'

resource 'Applications (prefix: /services/:service_id/applications)' do
  set_app ThreeScale::Backend::API::Internal
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'

  before do
    ThreeScale::Backend::Application.delete('7575', '100') rescue nil
    @app = ThreeScale::Backend::Application.save(service_id: '7575', id: '100',
                                                 plan_id: '9', plan_name: 'plan',
                                                 state: :active,
                                                 redirect_url: 'https://3scale.net')
  end

  get '/services/:service_id/applications/:id' do
    parameter :service_id, 'Service ID', required: true
    parameter :id, 'Application ID', required: true

    let(:service_id) { '7575' }
    let(:id) { '100' }
    let(:service_id_non_existent) { service_id.to_i.succ.to_s }
    let(:id_non_existent) { id.to_i.succ.to_s }

    example_request 'Get Application by ID' do
      response_json['application']['id'].should == id
      response_json['application']['service_id'].should == service_id
      status.should == 200
    end

    example 'Try to get an Application by non-existent ID' do
      do_request id: id_non_existent
      status.should == 404
      response_json['error'].should =~ /application not found/i
    end

    example 'Try to get an Application by non-existent service ID' do
      do_request service_id: service_id_non_existent
      status.should == 404
      response_json['error'].should =~ /application not found/i
    end
  end

  post '/services/:service_id/applications/:id' do
    parameter :service_id, 'Service ID', required: true
    parameter :id, 'Application ID', required: true
    parameter :application, 'Application attributes', required: true

    let(:service_id) { '7575' }
    let(:id) { '200' }
    let(:plan_id) { '100' }
    let(:plan_name) { 'some_plan' }
    let(:state) { :active }
    let(:redirect_url) { 'https://3scale.net' }
    let(:application) do
      {
        service_id: service_id,
        id: id,
        plan_id: plan_id,
        plan_name: plan_name,
        state: state,
        redirect_url: redirect_url
      }
    end
    let(:raw_post){ params.to_json }

    example_request 'Create an Application' do
      status.should == 201
      response_json['status'].should == 'created'

      (app = ThreeScale::Backend::Application.load(service_id, id)).should_not be_nil
      app.id.should == id
      app.service_id.should == service_id
      app.state.should == state
      app.plan_id.should == plan_id
      app.plan_name.should == plan_name
      app.redirect_url.should == redirect_url
      app.version.should == '1'
    end

  end

  put '/services/:service_id/applications/:id' do
    parameter :service_id, 'Service ID', required: true
    parameter :id, 'Application ID', required: true
    parameter :application, 'Application attributes', required: true

    let(:service_id) { '7575' }
    let(:id) { '100' }
    let(:plan_id) { '101' }
    let(:plan_name) { 'some_other_plan' }
    let(:state) { :active }
    let(:redirect_url) { 'https://3scale.net' }
    let(:application) do
      {
        service_id: service_id,
        id: id,
        plan_id: plan_id,
        plan_name: plan_name,
        state: state,
        redirect_url: redirect_url
      }
    end
    let(:raw_post){ params.to_json }

    example_request 'Update Service by ID' do
      status.should == 200
      response_json['status'].should == 'modified'

      (app = ThreeScale::Backend::Application.load(service_id, id)).should_not be_nil
      app.id.should == id
      app.service_id.should == service_id
      app.state.should == state
      app.plan_id.should == plan_id
      app.plan_name.should == plan_name
      app.redirect_url.should == redirect_url
      # since we've just modified an App, we should get version 2
      app.version.should == '2'
    end

  end

  delete '/services/:service_id/applications/:id' do
    parameter :service_id, 'Service ID', required: true
    parameter :id, 'Application ID', required: true

    let(:service_id) { '7575' }
    let(:id) { '100' }
    example_request 'Deleting an application' do
      status.should == 200
      response_json['status'].should == 'deleted'
    end

  end

  # XXX Old API. DEPRECATED.
  get '/services/:service_id/applications/key/:user_key' do
    parameter :service_id, 'Service ID', required: true
    parameter :user_key, 'User key for this Application', required: true

    let(:service_id) { '7575' }
    let(:id) { '100' }
    let(:user_key) { 'some_key' }
    let(:nonexistent_key) { 'nonexistent' }

    example 'Get existing ID of Application with service and key' do
      ThreeScale::Backend::Application.save_id_by_key(service_id, user_key, id)
      do_request
      status.should == 200
      response_json['application']['id'].should == id
    end

    example 'Try to get an Application ID from a non-existing key' do
      ThreeScale::Backend::Application.delete_id_by_key(service_id, nonexistent_key)
      do_request user_key: nonexistent_key
      status.should == 404
      response_json['error'].should =~ /not found/i
    end
  end

  put '/services/:service_id/applications/:id/key/:user_key' do
    parameter :service_id, 'Service ID', required: true
    parameter :id, 'Application ID', required: true
    parameter :user_key, 'User key for this Application', required: true

    let(:service_id) { '7575' }
    let(:id) { '100' }
    let(:user_key) { 'some_key' }
    let(:another_key) { 'another_key' }

    example 'Change the key for an Application' do
      ThreeScale::Backend::Application.save_id_by_key(service_id, user_key, id)
      do_request user_key: another_key
      status.should == 200
      response_json['status'].should == 'modified'
      ThreeScale::Backend::Application.
        load_id_by_key(service_id, another_key).should == id
    end
  end

  delete '/services/:service_id/applications/key/:user_key' do
    parameter :service_id, 'Service ID', required: true
    parameter :user_key, 'User key for this Application', required: true

    let(:service_id) { '7575' }
    let(:id) { '100' }
    let(:user_key) { 'some_key' }

    example 'Delete an Application\'s user key' do
      ThreeScale::Backend::Application.save_id_by_key(service_id, user_key, id)
      do_request
      status.should == 200
      response_json['status'].should == 'deleted'
      ThreeScale::Backend::Application.
        load_id_by_key(service_id, user_key).should be_nil
    end
  end
end
