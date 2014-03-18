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

  get '/list_ids/:provider_key' do
    parameter :provider_key, "Service provider key"

    example_request "Get ID list by provider_key", :provider_key => 'foo' do
      response_json.should == ['1001']
      status.should == 200
    end
  end

end

