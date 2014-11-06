require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class LogRequestTest < Test::Unit::TestCase
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::StorageKeys
  include Backend::Alerts

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!
    Memoizer.reset!

    setup_provider_fixtures

    @application_id1 = next_id
    Application.save(:service_id => @service_id,
                     :id         => @application_id1,
                     :plan_id    => @plan_id,
                     :state      => :active)

    @application_id2 = next_id
    Application.save(:service_id => @service_id,
                     :id         => @application_id2,
                     :plan_id    => @plan_id,
                     :state      => :active)

    @application_id3 = next_id
    Application.save(:service_id => @service_id,
                     :id         => @application_id3,
                     :plan_id    => @plan_id,
                     :state      => :active)


    @foos_id = next_id
    Metric.save(:service_id => @service_id, :id => @foos_id, :name => 'foos')

    UsageLimit.save(:service_id => @service_id,
                    :plan_id    => @plan_id,
                    :metric_id  => @foos_id,
                    :month        => 100)
  end

  test 'test empty responses' do
    get "/services/#{@service_id}/log_requests.xml", :provider_key => @provider_key

    assert_equal 200, last_response.status
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 1, doc.search('log_requests').size
    assert_equal 0, doc.search('log_request').size

    get "/services/#{@service_id}/applications/#{@application_id1}/log_requests.xml",   :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 1, doc.search('log_requests').size
    assert_equal 0, doc.search('log_request').size
  end

  test 'test empty deletes' do
    delete "/services/#{@service_id}/log_requests.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    assert_equal "", last_response.body

    delete "/services/#{@service_id}/applications/#{@application_id1}/log_requests.xml",   :provider_key => @provider_key
    assert_equal 200, last_response.status
    assert_equal "", last_response.body
  end

  test 'test errors on the parameters' do
    get "/services/#{@service_id}/log_requests.xml", :provider_key => "fake_provider_key"
    doc   = Nokogiri::XML(last_response.body)
    error = doc.at('error:root')
    assert_not_nil error
    assert_equal 'provider_key_invalid', error['code']
    assert_equal 403, last_response.status

    get "/services/fake_service_id/log_requests.xml", :provider_key => @provider_key
    doc   = Nokogiri::XML(last_response.body)
    error = doc.at('error:root')
    assert_not_nil error
    assert_equal 'provider_key_invalid', error['code']
    assert_equal 403, last_response.status

    get "/services/#{@service_id}/log_requests.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 1, doc.search('log_requests').size
    assert_equal 0, doc.search('log_request').size

    get "/services/#{@service_id}/applications/#{@application_id1}/log_requests.xml", :provider_key => "fake_provider_key"
    doc   = Nokogiri::XML(last_response.body)
    error = doc.at('error:root')
    assert_not_nil error
    assert_equal 'provider_key_invalid', error['code']
    assert_equal 403, last_response.status

    get "/services/#{@service_id}/applications/fake_app_id/log_requests.xml", :provider_key => @provider_key
    doc   = Nokogiri::XML(last_response.body)
    error = doc.at('error:root')
    assert_not_nil error
    assert_equal 'application_not_found', error['code']
    assert_equal 404, last_response.status

    get "/services/#{@service_id}/applications/#{@application_id1}/log_requests.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 1, doc.search('log_requests').size
    assert_equal 0, doc.search('log_request').size
  end

  test 'test errors on the parameters for delete' do
    delete "/services/fake_service_id/log_requests.xml", :provider_key => @provider_key
    doc   = Nokogiri::XML(last_response.body)
    error = doc.at('error:root')
    assert_not_nil error
    assert_equal 'provider_key_invalid', error['code']
    assert_equal 403, last_response.status

    delete "/services/#{@service_id}/applications/fake_app_id/log_requests.xml", :provider_key => @provider_key
    doc   = Nokogiri::XML(last_response.body)
    error = doc.at('error:root')
    assert_not_nil error
    assert_equal 'application_not_found', error['code']
    assert_equal 404, last_response.status

    delete "/services/#{@service_id}/log_requests.xml", :provider_key => "fake_provider_key"
    doc   = Nokogiri::XML(last_response.body)
    error = doc.at('error:root')
    assert_not_nil error
    assert_equal 'provider_key_invalid', error['code']
    assert_equal 403, last_response.status
  end

  test 'test correct results for alerts with report' do
    @log1 = {'request' => '/bla/bla/bla?query=bla&again=boo'}
    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id => @application_id1, :usage => {'foos' => 81}, :log => @log1}}
    2.times{ Resque.run! }

    get "/services/#{@service_id}/applications/#{@application_id1}/log_requests.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc1   = Nokogiri::XML(last_response.body)

    get "/services/#{@service_id}/log_requests.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc2   = Nokogiri::XML(last_response.body)

    assert_equal doc1.to_xml, doc2.to_xml

    assert_equal 1, doc1.search('log_requests').size
    assert_equal 1, doc1.search('log_request').size

    assert_equal @service_id, doc1.search('service_id')[0].content
    assert_equal @application_id1, doc1.search('app_id')[0].content
    assert_nil doc1.search('user_id')[0]
    assert_equal @log1['request'], doc1.search('request')[0].content
    assert_equal "N/A", doc1.search('response')[0].content
    assert_equal "N/A", doc1.search('code')[0].content
    assert_equal "foos: 81, ", doc1.search('usage')[0].content

    previous_doc = doc1

    @log1 = {'request' => '/bla/bla/bla?query=bla&again=boo', 'response' => 'response_text', 'code' => '200'}

    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id => @application_id1, :log => @log1}}
    2.times{ Resque.run! }

    get "/services/#{@service_id}/applications/#{@application_id1}/log_requests.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc1   = Nokogiri::XML(last_response.body)

    get "/services/#{@service_id}/log_requests.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc2   = Nokogiri::XML(last_response.body)

    assert_equal doc1.to_xml, doc2.to_xml

    assert_equal 1, doc1.search('log_requests').size
    assert_equal 2, doc1.search('log_request').size

    assert_equal @service_id, doc1.search('service_id')[0].content
    assert_equal @application_id1, doc1.search('app_id')[0].content
    assert_nil doc1.search('user_id')[0]
    assert_equal @log1['request'], doc1.search('request')[0].content
    assert_equal @log1['response'], doc1.search('response')[0].content
    assert_equal @log1['code'], doc1.search('code')[0].content
    assert_equal "N/A", doc1.search('usage')[0].content

    assert_equal doc1.search('log_request')[1].to_xml, previous_doc.search('log_request')[0].to_xml

    previous_doc = doc1

    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id => @application_id1, :usage => {'foos' => 81}}}

    2.times { Resque.run! }

    get "/services/#{@service_id}/applications/#{@application_id1}/log_requests.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc1   = Nokogiri::XML(last_response.body)

    get "/services/#{@service_id}/log_requests.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc2   = Nokogiri::XML(last_response.body)

    assert_equal doc1.to_xml, doc2.to_xml

    assert_equal 1, doc1.search('log_requests').size
    assert_equal 2, doc1.search('log_request').size

    assert_equal doc1.to_xml, previous_doc.to_xml

    post '/transactions.xml',
      :provider_key => @provider_key,
      :transactions => {0 => {:app_id => @application_id1, :usage => {'foos' => 81}, :log => @log1}, 1 => {:app_id => @application_id1, :log => @log1}, 2 => {:app_id => @application_id2, :usage => {'foos' => 81}, :log => @log1}}

    2.times{ Resque.run! }

    get "/services/#{@service_id}/applications/#{@application_id1}/log_requests.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc1   = Nokogiri::XML(last_response.body)

    get "/services/#{@service_id}/log_requests.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc2   = Nokogiri::XML(last_response.body)

    assert_not_equal doc1.to_xml, doc2.to_xml

    assert_equal 1, doc1.search('log_requests').size
    assert_equal 4, doc1.search('log_request').size

    assert_equal 1, doc2.search('log_requests').size
    assert_equal 5, doc2.search('log_request').size
  end


  test 'test correct results for alerts with authrep' do
    @log1 = {'request' => '/bla/bla/bla?query=bla&again=boo'}

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_id1,
                                     :usage        => {'foos' => 81},
                                     :log          => @log1
    2.times{ Resque.run! }

    get "/services/#{@service_id}/applications/#{@application_id1}/log_requests.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc1   = Nokogiri::XML(last_response.body)

    get "/services/#{@service_id}/log_requests.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc2   = Nokogiri::XML(last_response.body)

    assert_equal doc1.to_xml, doc2.to_xml

    assert_equal 1, doc1.search('log_requests').size
    assert_equal 1, doc1.search('log_request').size

    assert_equal @service_id, doc1.search('service_id')[0].content
    assert_equal @application_id1, doc1.search('app_id')[0].content
    assert_nil doc1.search('user_id')[0]
    assert_equal @log1['request'], doc1.search('request')[0].content
    assert_equal "N/A", doc1.search('response')[0].content
    assert_equal "N/A", doc1.search('code')[0].content
    assert_equal "foos: 81, ", doc1.search('usage')[0].content

    previous_doc = doc1

    @log1 = {'request' => '/bla/bla/bla?query=bla&again=boo', 'response' => 'response_text', 'code' => '200'}

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_id1,
                                     :log          => @log1
    2.times{ Resque.run! }

    get "/services/#{@service_id}/applications/#{@application_id1}/log_requests.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc1   = Nokogiri::XML(last_response.body)

    get "/services/#{@service_id}/log_requests.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc2   = Nokogiri::XML(last_response.body)

    assert_equal doc1.to_xml, doc2.to_xml

    assert_equal 1, doc1.search('log_requests').size
    assert_equal 2, doc1.search('log_request').size

    assert_equal @service_id, doc1.search('service_id')[0].content
    assert_equal @application_id1, doc1.search('app_id')[0].content
    assert_nil doc1.search('user_id')[0]
    assert_equal @log1['request'], doc1.search('request')[0].content
    assert_equal @log1['response'], doc1.search('response')[0].content
    assert_equal @log1['code'], doc1.search('code')[0].content
    assert_equal "N/A", doc1.search('usage')[0].content

    assert_equal doc1.search('log_request')[1].to_xml, previous_doc.search('log_request')[0].to_xml

    previous_doc = doc1


    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_id1,
                                     :usage        => {'foos' => 81}
    2.times { Resque.run! }

    get "/services/#{@service_id}/applications/#{@application_id1}/log_requests.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc1   = Nokogiri::XML(last_response.body)

    get "/services/#{@service_id}/log_requests.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc2   = Nokogiri::XML(last_response.body)

    assert_equal doc1.to_xml, doc2.to_xml

    assert_equal 1, doc1.search('log_requests').size
    assert_equal 2, doc1.search('log_request').size

    assert_equal doc1.to_xml, previous_doc.to_xml
  end


  # regression test for bug https://3scale.airbrake.io/errors/51189322
  #
  test 'check that logs can be properly encoded before storing' do

    log1 = {'request' => 'shop/caf\xe9'}

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_id1,
                                     :usage        => {'foos' => 5},
                                     :log          => log1
    assert_equal 200, last_response.status
    2.times{ Resque.run! }

    get "/services/#{@service_id}/applications/#{@application_id1}/log_requests.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc1   = Nokogiri::XML(last_response.body)
    assert_equal 1, doc1.search('log_request').size
    assert_equal log1['request'], doc1.search('request')[0].content

    # now with the double quotes should not store the log entry but a warning message

    log1 = {'request' => "shop/caf\xe9"}

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_id1,
                                     :usage        => {'foos' => 6},
                                     :log          => log1
    assert_equal 200, last_response.status
    2.times{ Resque.run! }

    get "/services/#{@service_id}/applications/#{@application_id1}/log_requests.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc1   = Nokogiri::XML(last_response.body)
    assert_equal 2, doc1.search('log_request').size
    assert_equal "Error: the log entry could not be stored. Please use UTF8 encoding.", doc1.search('request')[0].content

    # building the path as a string

    path = '/transactions/authrep.xml?provider_key=' + @provider_key + '&'
    path = path + "app_id=" + @application_id1 + '&'
    path = path + "log[request]=" + URI.encode('shop/caf\xe9')

    get path
    assert_equal 200, last_response.status
    2.times{ Resque.run! }

    assert_equal 'shop/caf\xe9', URI.decode(URI.encode('shop/caf\xe9'))
    get "/services/#{@service_id}/applications/#{@application_id1}/log_requests.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc1   = Nokogiri::XML(last_response.body)
    assert_equal 3, doc1.search('log_request').size

    # building the path as a string playing with quotes

    path = '/transactions/authrep.xml?provider_key=' + @provider_key + '&'
    path = path + "app_id=" + @application_id1 + '&'
    path = path + "log[request]=" + URI.encode('"shop/caf\xe9"')

    get path
    assert_equal 200, last_response.status
    2.times{ Resque.run! }

    assert_equal '"shop/caf\xe9"', URI.decode(URI.encode('"shop/caf\xe9"'))
    get "/services/#{@service_id}/applications/#{@application_id1}/log_requests.xml", :provider_key => @provider_key
    assert_equal 200, last_response.status
    doc1   = Nokogiri::XML(last_response.body)
    assert_equal 4, doc1.search('log_request').size

  end




end
