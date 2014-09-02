require_relative '../../acceptance_spec_helper'

resource "Services (prefix: /services)" do
  set_app ThreeScale::Backend::API::ServicesAPI
  header "Accept", "application/json"
  header "Content-Type", "application/json"

  before do
    @service = ThreeScale::Backend::Service.save!(provider_key: 'foo', id: '1001')
  end

  get '/:id' do
    parameter :id, "Service ID", required: true

    example_request "Get Service by ID", :id => 1001 do
      response_json['id'].should == '1001'
      status.should == 200
    end

    example_request 'Try to get a Service by non-existent ID', id: 1002 do
      status.should == 404
      response_json['error'].should =~ /not_found/
    end
  end

  post '/' do
    parameter :service, 'Service attributes', required: true

    let(:service) do
      {
        id: '1002',
        provider_key: 'foo',
        referrer_filters_required: true,
        backend_version: 'oauth',
        default_user_plan_name: 'default user plan name',
        default_user_plan_id: 'plan ID',
        default_service: true
      }
    end
    let(:raw_post){ params.to_json }

    example_request 'Create a Service' do
      status.should == 201
      response_json['status'].should == 'created'

      (service = ThreeScale::Backend::Service.load_by_id('1002')).should_not be_nil
      service.provider_key.should == 'foo'
      service.referrer_filters_required?.should be_true
      service.backend_version.should == 'oauth'
      service.default_user_plan_name.should == 'default user plan name'
      service.default_user_plan_id.should == 'plan ID'
      service.default_service?.should be_true
    end

    example 'Try updating Service with invalid data' do
      do_request service: {user_registration_required: false}

      status.should == 400
      response_json['error'].should =~ /require a default user plan/
    end
  end

  put '/:id' do
    parameter :id, 'Service ID', required: true
    parameter :service, 'Service attributes', required: true

    let(:id){ 1001 }
    let(:service) do
      {
        provider_key: 'foo',
        referrer_filters_required: true,
        backend_version: 'oauth',
        default_user_plan_name: 'default user plan name',
        default_user_plan_id: 'plan ID'
      }
    end
    let(:raw_post){ params.to_json }

    example_request 'Update Service by ID' do
      status.should == 200
      response_json['status'].should == 'ok'

      (service = ThreeScale::Backend::Service.load_by_id('1001')).should_not be_nil
      service.provider_key.should == 'foo'
      service.referrer_filters_required?.should be_true
      service.backend_version.should == 'oauth'
      service.default_user_plan_name.should == 'default user plan name'
      service.default_user_plan_id.should == 'plan ID'
    end

    example 'Try updating Service with invalid data' do
      do_request service: {user_registration_required: false}

      status.should == 400
      response_json['error'].should =~ /require a default user plan/
    end
  end

  put '/change_provider_key/:key' do
    parameter :key, 'Existing provider key', required: true
    parameter :new_key, 'New provider key', required: true

    let(:key){ 'foo' }
    let(:new_key){ 'bar' }
    let(:raw_post) { params.to_json }

    example_request 'Changing a provider key'do
      status.should == 200
      response_json['status'].should == 'ok'
    end

    example_request 'Trying to change a provider key to empty', new_key: '' do
      status.should == 400
      response_json['error'].should =~ /keys are not valid/
    end

    example 'Trying to change a provider key to an existing one' do
      ThreeScale::Backend::Service.save! id: 7002, provider_key: 'bar'
      do_request new_key: 'bar'

      status.should == 400
      response_json['error'].should =~ /already exists/
    end

    example_request 'Trying to change a non-existent provider key', key: 'baz' do
      status.should == 400
      response_json['error'].should =~ /does not exist/
    end
  end

  delete '/:id' do
    parameter :id, 'Service ID', required: true

    let(:raw_post) { params.to_json }

    example_request 'Deleting a default service', id: 1001 do
      status.should == 400
      response_json['error'].should =~ /cannot be removed/
    end

    example 'Deleting a non-default service' do
      ThreeScale::Backend::Service.save!(provider_key: 'foo', id: 1002)
      do_request id: 1002

      status.should == 200
      response_json['status'].should == 'ok'
    end
  end

  post '/:id/users' do
    let(:raw_post) { params.to_json }

    parameter :id, 'Service ID', required: true
    parameter :username, 'Username to add', required: true

    example_request 'Adding a user to a service', id: 1001, username: 'bar' do
      expect(status).to eq 200
      expect(response_json['status']).to eq 'ok'
    end
  end

  delete '/:id/users/:username' do
    parameter :id, 'Service ID', required: true
    parameter :username, 'Username to delete', required: true

    example 'Removing a user from a service' do
      ThreeScale::Backend::ServiceUserManagementUseCase.new(@service, 'bar').add

      do_request id: 1001, username: 'bar'
      expect(status).to eq 200
      expect(response_json['status']).to eq 'ok'
    end
  end

end
