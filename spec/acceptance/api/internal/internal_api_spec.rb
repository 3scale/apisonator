require_relative '../../acceptance_spec_helper'

resource 'Internal API (prefix: /internal)' do
  set_app ThreeScale::Backend::API::Internal
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'

  get '/check.json' do
    example_request 'Check internal API live status' do
      status.should == 200
      response_json['status'].should == 'ok'
    end
  end

  get '/version' do
    example_request 'Get Backend\'s version' do
      status.should == 200
      response_json['version']['backend'].should == ThreeScale::Backend::VERSION
    end
  end
end
