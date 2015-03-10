require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class LatestTransactionsTest < Test::Unit::TestCase
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::StorageKeys

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!
    Memoizer.reset!

    setup_provider_fixtures

    @application_id = next_id
    Application.save(:service_id => @service_id,
                     :id         => @application_id,
                     :plan_id    => @plan_id,
                     :state      => :active)

    @foos_id = next_id
    Metric.save(:service_id => @service_id, :id => @foos_id, :name => 'foos')

    @bars_id = next_id
    Metric.save(:service_id => @service_id, :id => @bars_id, :name => 'bars')
  end

  test 'OPTION /transactions/latest.xml returns GET' do
    request '/transactions/latest.xml',
      :method => 'OPTIONS',
      :params => {:provider_key => @provider_key}

    assert_equal 200,   last_response.status
    assert_equal 'GET', last_response.headers['Allow']
  end

  test 'GET /transactions/latest.xml returns list of latest transactions' do
    Timecop.freeze(Time.utc(2010, 9, 9, 0, 0)) do
      Transactor.report(@provider_key, @service_id, 0 => {'app_id'    => @application_id,
                                            'usage'     => {'foos' => 1},
                                            'timestamp' => '2010-09-09 11:00:00'})
      Resque.run!

      Transactor.report(@provider_key, @service_id, 0 => {'app_id'    => @application_id,
                                            'usage'     => {'bars' => 2},
                                            'timestamp' => '2010-09-09 12:00:00'})
      Resque.run!

      get '/transactions/latest.xml', :provider_key => @provider_key

      assert_equal 200, last_response.status

      doc = Nokogiri::XML(last_response.body)
      nodes = doc.search('transactions:root transaction')

      assert_equal 2, nodes.size

      assert_equal @application_id,             nodes[0]['application_id']
      assert_equal '2010-09-09 12:00:00 +0000', nodes[0]['timestamp']
      assert_equal '2', nodes[0].at("value[metric_id = \"#{@bars_id}\"]").content

      assert_equal @application_id,             nodes[1]['application_id']
      assert_equal '2010-09-09 11:00:00 +0000', nodes[1]['timestamp']
      assert_equal '1', nodes[1].at("value[metric_id = \"#{@foos_id}\"]").content
    end
  end

  test 'GET /transactions/latest.xml returns at most 50 transactions' do
    60.times do
      Transactor.report(@provider_key, nil, 0 => {'app_id'    => @application_id,
                                             'usage'     => {'bars' => 2}})
    end
    Resque.run!

    get '/transactions/latest.xml', :provider_key => @provider_key

    assert_equal 200, last_response.status
    assert_equal 50, Nokogiri::XML(last_response.body).search('transaction').size
  end
end
