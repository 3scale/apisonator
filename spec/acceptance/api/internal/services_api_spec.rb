require_relative '../../acceptance_spec_helper'

resource "Services (prefix: /services)" do
  set_app ThreeScale::Backend::ServicesAPI
  header "Accept", "application/json"

  before do
    ThreeScale::Backend::Service.save!(provider_key: 'foo', id: '1001')
  end

  get "/:id" do
    parameter :id, "Service ID", required: true

    example_request "Get Service by ID", :id => 1001 do
      response_json['id'].should == '1001'
      status.should == 200
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
  end

  delete '/:id' do
    parameter :id, 'Service ID', required: true
    parameter :force, 'Delete even if set as default service'

    example_request 'Deleting a default service', id: 1001 do
      status.should == 400
      response_json['error'].should =~ /must be removed forcefully/
    end

    example_request 'Forcing a deletion of a default service', id: 1001, force: true do
      status.should == 200
      response_json['status'].should == 'ok'
    end

    example 'Deleting a non-default service' do
      ThreeScale::Backend::Service.save!(provider_key: 'foo', id: 1002)
      do_request id: 1002

      status.should == 200
      response_json['status'].should == 'ok'
    end
  end

  get '/' do
    parameter :provider_key, "Service provider key", required: true

    example_request "Get ID list by provider_key", :provider_key => 'foo' do
      response_json.should == ['1001']
      status.should == 200
    end
  end

end
