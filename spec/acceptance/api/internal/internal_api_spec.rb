require_relative '../../acceptance_spec_helper'

resource 'Internal API (prefix: /internal)' do
  set_app ThreeScale::Backend::API::Internal
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'

  get '/unknown/route/no/one/would/ever/try/to/use/in/a/real/app/omg' do
    example_request 'Check that unknown routes return proper 404' do
      status.should == 404
      response_json['status'].should == 'not_found'
      response_json['error'].should == 'Not found'
    end
  end

  get '/check.json' do
    example_request 'Check internal API live status' do
      status.should == 200
      response_json['status'].should == 'ok'
    end
  end

  get '/status' do
    example_request 'Get Backend\'s version' do
      status.should == 200
      response_json['status'].should == 'ok'
      response_json['version']['backend'].should == ThreeScale::Backend::VERSION
    end
  end
end
