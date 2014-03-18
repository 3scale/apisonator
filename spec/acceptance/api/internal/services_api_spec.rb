require_relative '../../acceptance_spec_helper'

resource "Services (prefix: /services)" do
  set_app ThreeScale::Backend::ServicesAPI
  header "Accept", "application/json"

  before do
    ThreeScale::Backend::Service.save!(:provider_key => 'foo', :id => '1001')
  end

  get "/:id" do
    parameter :id, "Service ID"

    example_request "Get Service by ID", :id => 1001 do
      response_json['id'].should == '1001'
      status.should == 200
    end
  end

  put '/:id' do
    parameter :id, 'Service ID'

    update_data = {
      provider_key: 'foo',
      referrer_filters_required: true,
      backend_version: 'oauth',
      default_user_plan_name: 'default user plan name',
      default_user_plan_id: 'plan ID'
    }

    example_request 'Update Service by ID', id: 7001, service: update_data do
      status.should == 200
      response_json['status'].should == 'ok'

      (service = ThreeScale::Backend::Service.load_by_id('7001')).should_not be_nil
      service.provider_key.should == 'foo'
      service.referrer_filters_required?.should be_true
      service.backend_version.should == 'oauth'
      service.default_user_plan_name.should == 'default user plan name'
      service.default_user_plan_id.should == 'plan ID'
    end
  end

  get '/list_ids/:provider_key' do
    parameter :provider_key, "Service provider key"

    example_request "Get ID list by provider_key", :provider_key => 'foo' do
      response_json.should == ['1001']
      status.should == 200
    end
  end

end

