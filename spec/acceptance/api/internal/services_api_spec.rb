require_relative '../../../spec_helper'

resource "Services (prefix: /services)" do
  set_app ThreeScale::Backend::ServicesAPI
  header "Accept", "application/json"

  before do
    ThreeScale::Backend::Service.save!(:provider_key => 'foo', :id => '1001')
  end

  get "/" do
    parameter :id, "Service ID"
    parameter :provider_key, "Service provider key"

    example_request "Get Service by ID", :id => 1001 do
      response_json['id'].should == '1001'
      status.should == 200
    end

    example_request "Get Service by provider key", :provider_key => 'foo' do
      response_json['provider_key'].should == 'foo'
      status.should == 200
    end
  end

  get '/list_ids' do
    parameter :provider_key, "Service provider key"

    example_request "Get ID list by provider_key", :provider_key => 'foo' do
      response_json.should == ['1001']
      status.should == 200
    end
  end

end

