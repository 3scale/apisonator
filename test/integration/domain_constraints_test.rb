require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class DomainConstraintsTest < Test::Unit::TestCase
  include TestHelpers::Integration
  include TestHelpers::Sequences
  
  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!

    @provider_key = 'provider_key'
    @service_id   = next_id
    Core::Service.save(:provider_key => @provider_key, :id => @service_id)

    @application_id = next_id
    Application.save(:service_id => @service_id, 
                     :id         => @application_id,
                     :state      => :active)
  end

  test 'OPTIONS /applications/{app_id}/constraints/domains.xml returns GET and POST' do
    request "/applications/#{@application_id}/constraints/domains.xml", 
      :method => 'OPTIONS',
      :params => {:provider_key => @provider_key}

    assert_equal 200,         last_response.status
    assert_equal 'GET, POST', last_response.headers['Allow']
  end
end
