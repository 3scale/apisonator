require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class CacheTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::StorageKeys

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!
    Memoizer.reset!
    
    setup_provider_fixtures

    @application = Application.save(:service_id => @service.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id,
                                    :plan_name  => @plan_name)

    @metric_id = next_id
    Metric.save(:service_id => @service.id, :id => @metric_id, :name => 'hits')

  end

  test 'caching of referrals with wildcards is not effective' do 

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day        => 100)

    @service.referrer_filters_required = true
    @service.save!
  
    referrer = @application.create_referrer_filter('*.bar.example.org')

    Transactor.stats = {:miss => 0, :count => 0}

    3.times do
      get '/transactions/authrep.xml',  :provider_key => @provider_key,
                                        :app_id       => @application.id,
                                        :usage        => {'hits' => 1},
                                        :referrer     => 'www.bar.example.org'
      Resque.run!
    end

    doc   = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_equal 'true', doc.at('status:root authorized').content
    assert_equal 200, last_response.status
    assert_equal '3', day.at('current_value').content

    assert_equal 3, Transactor.stats[:miss]
    assert_equal 3, Transactor.stats[:count]


    Transactor.stats = {:miss => 0, :count => 0}
    referrer = @application.create_referrer_filter('another.referral')
    referrer = @application.create_referrer_filter('www.bar.example.org')

    app_key = @application.create_key("app_key1")
    @application.create_key("app_key2")
    @application.create_key("app_key3")


    3.times do
      get '/transactions/authrep.xml',  :provider_key => @provider_key,
                                        :app_id       => @application.id,
                                        :app_key      => app_key,
                                        :usage        => {'hits' => 1},
                                        :referrer     => 'www.bar.example.org'
      Resque.run!
    end

    doc   = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_equal 'true', doc.at('status:root authorized').content
    assert_equal 200, last_response.status
    assert_equal '6', day.at('current_value').content

    assert_equal 1, Transactor.stats[:miss]
    assert_equal 3, Transactor.stats[:count]


  end

  test 'caching with referrals with authrep' do

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day        => 100)

    #old_referrer_filters = @service.referrer_filters_required
    @service.referrer_filters_required = true
    @service.save!
  
    app_key = @application.create_key("app_key")
    referrer = @application.create_referrer_filter('*.bar.example.org')

    get '/transactions/authrep.xml',  :provider_key => @provider_key,
                                      :app_id       => @application.id,
                                      :app_key      => app_key,
                                      :usage        => {'hits' => 1}

    Resque.run!
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 'false', doc.at('status:root authorized').content
    assert_equal 409, last_response.status

    3.times do
      get '/transactions/authrep.xml',  :provider_key => @provider_key,
                                        :app_id       => @application.id,
                                        :app_key      => app_key,
                                        :usage        => {'hits' => 1},
                                        :referrer     => 'www.bar.example.org'
      Resque.run!
    end
    doc   = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_equal 'true', doc.at('status:root authorized').content
    assert_equal 200, last_response.status
    assert_equal '3', day.at('current_value').content

    get '/transactions/authrep.xml',  :provider_key => @provider_key,
                                      :app_id       => @application.id,
                                      :app_key      => app_key,
                                      :usage        => {'hits' => 1},
                                      :referrer     => 'fake'
    Resque.run!
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 'false', doc.at('status:root authorized').content
    assert_equal 409, last_response.status
  
    get '/transactions/authrep.xml',  :provider_key => @provider_key,
                                      :app_id       => @application.id,
                                      :app_key      => app_key,
                                      :usage        => {'hits' => 1},
                                      :referrer     => 'www.bar.example.org'
    Resque.run!
    doc   = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_equal 'true', doc.at('status:root authorized').content
    assert_equal 200, last_response.status
    assert_equal '4', day.at('current_value').content

    get '/transactions/authrep.xml',  :provider_key => @provider_key,
                                      :app_id       => @application.id,
                                      :app_key      => app_key,
                                      :usage        => {'hits' => 1},
                                      :referrer     => 'fake'
    Resque.run!
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 'false', doc.at('status:root authorized').content
    assert_equal 409, last_response.status

    
    @service.referrer_filters_required = false
    @service.save!

  end

  test 'caching with referrals with authorize' do

    ##Transactor.caching_disable
    
    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day        => 100)

    #old_referrer_filters = @service.referrer_filters_required
    @service.referrer_filters_required = true
    @service.save!
    tmp_last_response = nil
    app_key = @application.create_key("app_key")
    referrer = @application.create_referrer_filter('*.bar.example.org')

    get '/transactions/authorize.xml',  :provider_key => @provider_key,
                                        :app_id       => @application.id,
                                        :app_key      => app_key,
                                        :referrer     => 'www.bar'
    Resque.run!
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 'false', doc.at('status:root authorized').content
    assert_equal 409, last_response.status

    3.times do
      get '/transactions/authorize.xml',  :provider_key => @provider_key,
                                          :app_id       => @application.id,
                                          :app_key      => app_key,
                                          :referrer     => 'www.bar.example.org'
      tmp_last_response = last_response
      post '/transactions.xml',
              :provider_key => @provider_key,
              :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}}}
      Resque.run!
    end
    doc   = Nokogiri::XML(tmp_last_response.body)
    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_equal 'true', doc.at('status:root authorized').content
    assert_equal 200, tmp_last_response.status
    assert_equal '2', day.at('current_value').content

    get '/transactions/authorize.xml',  :provider_key => @provider_key,
                                        :app_id       => @application.id,
                                        :app_key      => app_key,
                                        :referrer     => 'fake'
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 'false', doc.at('status:root authorized').content
    assert_equal 409, last_response.status
  
    get '/transactions/authorize.xml',  :provider_key => @provider_key,
                                        :app_id       => @application.id,
                                        :app_key      => app_key,
                                        :referrer     => 'www.bar.example.org'
    tmp_last_response = last_response
    post '/transactions.xml',
            :provider_key => @provider_key,
            :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}}}
    Resque.run!
    doc   = Nokogiri::XML(tmp_last_response.body)
    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_equal 'true', doc.at('status:root authorized').content
    assert_equal 200, tmp_last_response.status
    assert_equal '3', day.at('current_value').content

    get '/transactions/authorize.xml',  :provider_key => @provider_key,
                                        :app_id       => @application.id,
                                        :app_key      => app_key,
                                        :usage        => {'hits' => 1},
                                        :referrer     => 'fake'
    Resque.run!
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 'false', doc.at('status:root authorized').content
    assert_equal 409, last_response.status
    
    @service.referrer_filters_required = false
    @service.save!


    ##Transactor.caching_enable

  end

  test 'caching considers metrics' do 
    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day        => 100)

    Transactor.stats = {:miss => 0, :count => 0}

    get '/transactions/authrep.xml',  :provider_key => @provider_key,
                                        :app_id       => @application.id,
                                        :usage        => {'hits' => 1, 'fake_metric' => 1}
    Resque.run!
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 403, last_response.status

    get '/transactions/authrep.xml',  :provider_key => @provider_key,
                                        :app_id       => @application.id,
                                        :usage        => {'hits' => 1, 'fake_metric' => 1}
    Resque.run!
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 403, last_response.status

    assert_equal Transactor.stats[:miss], 2
    assert_equal Transactor.stats[:count], 2

    get '/transactions/authrep.xml',  :provider_key => @provider_key,
                                        :app_id       => @application.id,
                                        :usage        => {'hits' => 1}
    Resque.run!
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 200, last_response.status

    get '/transactions/authrep.xml',  :provider_key => @provider_key,
                                        :app_id       => @application.id,
                                        :usage        => {'hits' => 1}
    Resque.run!
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 200, last_response.status


    assert_equal Transactor.stats[:miss], 3
    assert_equal Transactor.stats[:count], 4

    get '/transactions/authrep.xml',  :provider_key => @provider_key,
                                        :app_id       => @application.id,
                                        :usage        => {'hits' => 1, 'fake_metric' => 1}
    Resque.run!
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 403, last_response.status

    get '/transactions/authrep.xml',  :provider_key => @provider_key,
                                        :app_id       => @application.id,
                                        :usage        => {'hits' => 1, 'fake_metric' => 1}
    Resque.run!
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 403, last_response.status

    assert_equal Transactor.stats[:miss], 5
    assert_equal Transactor.stats[:count], 6


    get '/transactions/authrep.xml',  :provider_key => @provider_key,
                                        :app_id       => @application.id,
                                        :usage        => {'hits' => 1}

    Resque.run!
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 'true', doc.at('status:root authorized').content
    assert_equal 200, last_response.status
    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_equal '3', day.at('current_value').content

    assert_equal Transactor.stats[:miss], 5
    assert_equal Transactor.stats[:count], 7


  end


  test 'checking that modified redis setting/caching_enabled controls caching' do

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day        => 1000)

    app_key = @application.create_key("app_key1")
    app_key2 = @application.create_key("app_key2")

    current_state = Transactor.caching_enabled?
    Transactor.caching_enable
    tmp_last_response = ""

    Transactor.stats = {:miss => 0, :count => 0}

    5.times do    

      get '/transactions/authorize.xml',  :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :app_key      => app_key
      tmp_last_response = last_response

      post '/transactions.xml',
            :provider_key => @provider_key,
            :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}}}

      Resque.run!

    end

    doc   = Nokogiri::XML(tmp_last_response.body)

    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

    assert_equal 'true', doc.at('status:root authorized').content
    assert_equal 200, tmp_last_response.status
    assert_equal '4', day.at('current_value').content

    assert_equal Transactor.stats[:miss], 1
    assert_equal Transactor.stats[:count], 5


    Transactor.stats = {:miss => 0, :count => 0}

    5.times do    

      get '/transactions/authrep.xml',  :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :app_key      => app_key,
                                            :usage        => {'hits' => 1}
      tmp_last_response = last_response
      Resque.run!

    end

    doc   = Nokogiri::XML(tmp_last_response.body)

    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

    assert_equal 'true', doc.at('status:root authorized').content
    assert_equal 200, tmp_last_response.status
    assert_equal '10', day.at('current_value').content

    assert_equal Transactor.stats[:miss], 1
    assert_equal Transactor.stats[:count], 5

    Transactor.caching_disable

    Transactor.stats = {:miss => 0, :count => 0}

    5.times do    

      get '/transactions/authorize.xml',  :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :app_key      => app_key
      tmp_last_response = last_response
      post '/transactions.xml',
            :provider_key => @provider_key,
            :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}}}

      Resque.run!

    end

    doc   = Nokogiri::XML(tmp_last_response.body)

    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

    assert_equal 'true', doc.at('status:root authorized').content
    assert_equal 200, tmp_last_response.status
    assert_equal '14', day.at('current_value').content

    assert_equal Transactor.stats[:miss], 5
    assert_equal Transactor.stats[:count], 5

    Transactor.stats = {:miss => 0, :count => 0}

    5.times do    

      get '/transactions/authrep.xml',  :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :app_key      => app_key,
                                            :usage        => {'hits' => 1}
      tmp_last_response = last_response
      Resque.run!

    end

    doc   = Nokogiri::XML(tmp_last_response.body)

    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

    assert_equal 'true', doc.at('status:root authorized').content
    assert_equal 200, tmp_last_response.status
    assert_equal '20', day.at('current_value').content

    assert_equal Transactor.stats[:miss], 5
    assert_equal Transactor.stats[:count], 5

    Transactor.caching_enable
    Transactor.stats = {:miss => 0, :count => 0}

    5.times do    

      get '/transactions/authorize.xml',  :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :app_key      => app_key,
                                            :no_caching   => true
      tmp_last_response = last_response

      post '/transactions.xml',
            :provider_key => @provider_key,
            :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}}}

      Resque.run!

    end

    doc   = Nokogiri::XML(tmp_last_response.body)

    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

    assert_equal 'true', doc.at('status:root authorized').content
    assert_equal 200, tmp_last_response.status
    assert_equal '24', day.at('current_value').content

    assert_equal Transactor.stats[:miss], 5
    assert_equal Transactor.stats[:count], 5

    Transactor.stats = {:miss => 0, :count => 0}

    5.times do    

      get '/transactions/authrep.xml',  :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :app_key      => app_key,
                                            :usage        => {'hits' => 1},
                                            :no_caching   => true
      tmp_last_response = last_response
      Resque.run!

    end

    doc   = Nokogiri::XML(tmp_last_response.body)

    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

    assert_equal 'true', doc.at('status:root authorized').content
    assert_equal 200, tmp_last_response.status
    assert_equal '30', day.at('current_value').content

    assert_equal Transactor.stats[:miss], 5
    assert_equal Transactor.stats[:count], 5

    Transactor.caching_enable if current_state

  end
  

  test 'checking hit ratio with authorize and app_key' do 

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day        => 1000)

    app_key = @application.create_key("app_key1")
    app_key2 = @application.create_key("app_key2")

    keys = [app_key, app_key2, "fake_app_key"]

    Transactor.stats = {:count => 0, :miss =>0}

    assert_equal Transactor.stats[:miss], 0
    assert_equal Transactor.stats[:count], 0

    Timecop.freeze(Time.utc(2010, 5, 14)) do

      10.times do |i| 
        get '/transactions/authorize.xml',  :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :app_key      => keys[i%2],
                                            :usage        => {"hits" => 1}
        Resque.run!
      end

      assert_equal Transactor.stats[:miss], 10
      assert_equal Transactor.stats[:count], 10

      10.times do |i| 
        get '/transactions/authorize.xml',  :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :app_key      => keys[i%2],
                                            :usage        => {"hits" => 1}
        post '/transactions.xml',
            :provider_key => @provider_key,
            :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}}}

        Resque.run!

      end
      
      assert_equal Transactor.stats[:miss], 11
      assert_equal Transactor.stats[:count], 20

      9.times do |i|

        old_miss = Transactor.stats[:miss]

        get '/transactions/authorize.xml',  :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :app_key      => keys[i%keys.size],
                                            :usage        => {"hits" => 1}

        doc = Nokogiri::XML(last_response.body)

        if ((i+1)%3)==0
          assert_equal 'false', doc.at('status:root authorized').content
          assert_equal 409, last_response.status
          assert_equal Transactor.stats[:miss], old_miss+1
        else
          assert_equal 'true', doc.at('status:root authorized').content
          assert_equal 200, last_response.status
          assert_equal Transactor.stats[:miss], old_miss
        end
        
        if ((i+1)%3)!=0
          post '/transactions.xml',
              :provider_key => @provider_key,
              :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}}}
        end
        
        Resque.run!

      end


    end

  end

  test 'checking hit ratio with authrep and app_key' do 

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day        => 1000)

    app_key = @application.create_key("app_key1")
    app_key2 = @application.create_key("app_key2")

    keys = [app_key, app_key2, "fake_app_key"]

    Transactor.stats = {:count => 0, :miss =>0 }

    assert_equal Transactor.stats[:miss], 0
    assert_equal Transactor.stats[:count], 0

    Timecop.freeze(Time.utc(2010, 5, 14)) do

      10.times do |i| 
        get '/transactions/authrep.xml',    :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :app_key      => keys[i%2],
                                            :usage        => {"hits" => 1}

        Resque.run!
      end

      assert_equal Transactor.stats[:miss], 2
      assert_equal Transactor.stats[:count], 10

      9.times do |i|

        old_miss = Transactor.stats[:miss]

        get '/transactions/authrep.xml',    :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :app_key      => keys[i%keys.size],
                                            :usage        => {"hits" => 1}

        Resque.run!

        doc = Nokogiri::XML(last_response.body)

        if ((i+1)%3)==0
          assert_equal 'false', doc.at('status:root authorized').content
          assert_equal 409, last_response.status
          assert_equal Transactor.stats[:miss], old_miss+1
        else
          assert_equal 'true', doc.at('status:root authorized').content
          assert_equal 200, last_response.status
          assert_equal Transactor.stats[:miss], old_miss
        end

      end


    end

  end

 test 'checking hit ratio with authorize' do 

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day        => 1000)

    Transactor.stats = {:count => 0, :miss =>0}

    assert_equal Transactor.stats[:miss], 0
    assert_equal Transactor.stats[:count], 0

    Timecop.freeze(Time.utc(2010, 5, 14)) do

      5.times do |i| 
        get '/transactions/authorize.xml',  :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :usage        => {"hits" => 1}

        doc = Nokogiri::XML(last_response.body)
        assert_equal 'true', doc.at('status:root authorized').content
        assert_equal 200, last_response.status

        post '/transactions.xml',
            :provider_key => @provider_key,
            :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}}}

        Resque.run!

      end
      
      assert_equal Transactor.stats[:miss], 1
      assert_equal Transactor.stats[:count], 5

    end

  end

  test 'checking hit ratio with authrep' do 

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day        => 1000)

    Transactor.stats = {:count => 0, :miss =>0 }

    assert_equal Transactor.stats[:miss], 0
    assert_equal Transactor.stats[:count], 0

    Timecop.freeze(Time.utc(2010, 5, 14)) do

      5.times do |i| 
        get '/transactions/authrep.xml',    :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :usage        => {"hits" => 1}

        Resque.run!

        doc = Nokogiri::XML(last_response.body)
        assert_equal 'true', doc.at('status:root authorized').content
        assert_equal 200, last_response.status

      end

      assert_equal Transactor.stats[:miss], 1
      assert_equal Transactor.stats[:count], 5

    end

  end


  test 'updating values with app_keys with authrep' do 

    Timecop.freeze(Time.utc(2010, 5, 14)) do

      UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day        => 100)

      app_key = @application.create_key("app_key1")

      get '/transactions/authrep.xml',    :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :app_key      => app_key,
                                            :usage        => {"hits" => 1}

      Resque.run!
      doc   = Nokogiri::XML(last_response.body)

      usage_reports = doc.at('usage_reports')
      assert_not_nil usage_reports
      day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

      assert_equal 'true', doc.at('status:root authorized').content
      assert_equal 200, last_response.status
      assert_equal '1', day.at('current_value').content


      get '/transactions/authrep.xml',    :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :app_key      => app_key,
                                            :usage        => {"hits" => 10}

      Resque.run!
      doc   = Nokogiri::XML(last_response.body)

      usage_reports = doc.at('usage_reports')
      assert_not_nil usage_reports
      day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

      assert_equal 'true', doc.at('status:root authorized').content
      assert_equal 200, last_response.status
      assert_equal '11', day.at('current_value').content

      get '/transactions/authrep.xml',    :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :app_key      => "fake_app_key",
                                            :usage        => {"hits" => 10}

      Resque.run!
      doc   = Nokogiri::XML(last_response.body)

      usage_reports = doc.at('usage_reports')
      assert_not_nil usage_reports
      day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

      assert_equal 'false', doc.at('status:root authorized').content
      assert_equal 409, last_response.status
      assert_equal '11', day.at('current_value').content

      get '/transactions/authrep.xml',      :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :app_key      => app_key,
                                            :usage        => {"hits" => 10}

      Resque.run!
      doc   = Nokogiri::XML(last_response.body)

      usage_reports = doc.at('usage_reports')
      assert_not_nil usage_reports
      day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

      assert_equal 'true', doc.at('status:root authorized').content
      assert_equal 200, last_response.status
      assert_equal '21', day.at('current_value').content

      get '/transactions/authrep.xml',    :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :app_key      => app_key,
                                            :usage        => {"hits" => 200}
      Resque.run!
      doc   = Nokogiri::XML(last_response.body)
      
      usage_reports = doc.at('usage_reports')
      assert_not_nil usage_reports
      day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

      assert_equal 'false', doc.at('status:root authorized').content
      assert_equal 409, last_response.status
      assert_equal '21', day.at('current_value').content



    end


  end

  test 'updating values with app_keys with authorize' do 

    Timecop.freeze(Time.utc(2010, 5, 14)) do

      UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day        => 100)

      app_key = @application.create_key("app_key1")

      get '/transactions/authorize.xml',    :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :app_key      => app_key,
                                            :usage        => {"hits" => 1}
      Resque.run!
      doc   = Nokogiri::XML(last_response.body)

      usage_reports = doc.at('usage_reports')
      assert_not_nil usage_reports
      day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

      assert_equal 'true', doc.at('status:root authorized').content
      assert_equal 200, last_response.status
      assert_equal '0', day.at('current_value').content

      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 1}}}
      Resque.run!
      assert_equal 202, last_response.status


      get '/transactions/authorize.xml',    :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :app_key      => app_key,
                                            :usage        => {"hits" => 10}
      Resque.run!
      doc   = Nokogiri::XML(last_response.body)

      usage_reports = doc.at('usage_reports')
      assert_not_nil usage_reports
      day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

      assert_equal 'true', doc.at('status:root authorized').content
      assert_equal 200, last_response.status
      assert_equal '1', day.at('current_value').content

      post '/transactions.xml',
        :provider_key => @provider_key,
        :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 10}}}
      Resque.run!
      assert_equal 202, last_response.status


      get '/transactions/authorize.xml',    :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :app_key      => "fake_app_key",
                                            :usage        => {"hits" => 10}
      Resque.run!
      doc   = Nokogiri::XML(last_response.body)

      usage_reports = doc.at('usage_reports')
      assert_not_nil usage_reports
      day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

      assert_equal 'false', doc.at('status:root authorized').content
      assert_equal 409, last_response.status
      assert_equal '11', day.at('current_value').content

      get '/transactions/authorize.xml',    :provider_key => @provider_key,
                                            :app_id       => @application.id,
                                            :app_key      => app_key,
                                            :usage        => {"hits" => 200}
      Resque.run!
      doc   = Nokogiri::XML(last_response.body)
      
      usage_reports = doc.at('usage_reports')
      assert_not_nil usage_reports
      day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

      assert_equal 'false', doc.at('status:root authorized').content
      assert_equal 409, last_response.status
      assert_equal '11', day.at('current_value').content

    end


  end


  test 'checking correct behaviour of caching by app_key' do 

    get '/transactions/authorize.xml',    :provider_key => @provider_key,
                                          :app_id       => @application.id
                                          
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 'true', doc.at('status:root authorized').content
    assert_equal 200, last_response.status


    @application.create_key("app_key1")
    @application.create_key("app_key2")

    ## error is app_keys defined and not passed

    get '/transactions/authorize.xml',    :provider_key => @provider_key,
                                          :app_id       => @application.id
    Resque.run!
                                    
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 'false', doc.at('status:root authorized').content
    assert_equal 409, last_response.status

    ## checking that they can be remove and then it's fine
    
    @application.delete_key("app_key1")
    @application.delete_key("app_key2")


    get '/transactions/authorize.xml',    :provider_key => @provider_key,
                                          :app_id       => @application.id
    Resque.run!   

    doc   = Nokogiri::XML(last_response.body)
    assert_equal 'true', doc.at('status:root authorized').content
    assert_equal 200, last_response.status

    ## putting the app_keys back in place and checking that either key goes well and putting one 
    ## that does not exist gives an error. Then, checking that a good key does not get the cached
    ## error, and finally checking that a repeated bad key does not get the cached good result. 

    @application.create_key("app_key1")
    @application.create_key("app_key2")

    get '/transactions/authorize.xml',    :provider_key => @provider_key,
                                          :app_id       => @application.id,
                                          :app_key      => "app_key1" 
             
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 'true', doc.at('status:root authorized').content
    assert_equal 200, last_response.status


    get '/transactions/authorize.xml',    :provider_key => @provider_key,
                                          :app_id       => @application.id,
                                          :app_key      => "app_key2"
                                    
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 'true', doc.at('status:root authorized').content
    assert_equal 200, last_response.status

    
    get '/transactions/authorize.xml',    :provider_key => @provider_key,
                                          :app_id       => @application.id,
                                          :app_key      => "fake_app_key2"
                                        
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 'false', doc.at('status:root authorized').content
    assert_equal 409, last_response.status

    get '/transactions/authorize.xml',    :provider_key => @provider_key,
                                          :app_id       => @application.id,
                                          :app_key      => "fake_app_key2"
                                        
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 'false', doc.at('status:root authorized').content
    assert_equal 409, last_response.status

    get '/transactions/authorize.xml',    :provider_key => @provider_key,
                                          :app_id       => @application.id,
                                          :app_key      => "app_key2"
                     
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 'true', doc.at('status:root authorized').content
    assert_equal 200, last_response.status


    get '/transactions/authorize.xml',    :provider_key => @provider_key,
                                          :app_id       => @application.id,
                                          :app_key      => "fake_app_key2"

                                    
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 'false', doc.at('status:root authorized').content
    assert_equal 409, last_response.status


  end

  test 'cached vs. non-cached authrep' do

    cached = []
    not_cached = []
    caching_was_enabled = Transactor.caching_enabled?

    Timecop.freeze(Time.utc(2010, 5, 14)) do

      @application = Application.save(:service_id => @service.id,
                                      :id         => next_id,
                                      :state      => :active,
                                      :plan_id    => @plan_id,
                                      :plan_name  => @plan_name)
     
      Metric.save(:service_id => @service.id, :id => @metric_id, :name => 'hits')

      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :day        => 100)

      11.times do |i|
        get '/transactions/authrep.xml', :provider_key => @provider_key,
                                         :app_id       => @application.id,
                                         :usage        => {'hits' => 10}
        Resque.run!

        cached << last_response.body

      end

      @application = Application.save(:service_id => @service.id,
                                      :id         => next_id,
                                      :state      => :active,
                                      :plan_id    => @plan_id,
                                      :plan_name  => @plan_name)

      Metric.save(:service_id => @service.id, :id => @metric_id, :name => 'hits')

      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :day        => 100)

      Transactor.caching_disable

      11.times do |i|
        get '/transactions/authrep.xml', :provider_key => @provider_key,
                                         :app_id       => @application.id,
                                         :usage        => {'hits' => 10}
        Resque.run!

        not_cached << last_response.body

      end

    end  

    10.times do |i|
      assert_not_nil  cached[i]
      assert_equal    cached[i], not_cached[i]
      assert_not_equal  cached[i], cached[i-1] if i>0
      assert_not_equal  not_cached[i], not_cached[i-1] if i>0

      doc   = Nokogiri::XML(cached[i])
      assert_equal 'true', doc.at('status:root authorized').content

    end
  
    doc   = Nokogiri::XML(cached[10])
    assert_equal 'false', doc.at('status:root authorized').content
    doc   = Nokogiri::XML(not_cached[10])
    assert_equal 'false', doc.at('status:root authorized').content

    Transactor.caching_enable if caching_was_enabled
    
  end

  test 'cached vs. non-cached authorize' do

    cached = []
    not_cached = []
    caching_was_enabled = Transactor.caching_enabled?

    Timecop.freeze(Time.utc(2010, 5, 14)) do

      @application = Application.save(:service_id => @service.id,
                                      :id         => next_id,
                                      :state      => :active,
                                      :plan_id    => @plan_id,
                                      :plan_name  => @plan_name)

      app_key = @application.create_key("app_key1")

      Metric.save(:service_id => @service.id, :id => @metric_id, :name => 'hits')

      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :day        => 100)

      12.times do |i|
        get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id       => @application.id,
                                         :app_key      => app_key

        cached << last_response.body

        post '/transactions.xml',
            :provider_key => @provider_key,
            :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 10}}}
        Resque.run!


      end

      @application = Application.save(:service_id => @service.id,
                                      :id         => next_id,
                                      :state      => :active,
                                      :plan_id    => @plan_id,
                                      :plan_name  => @plan_name)

      app_key = @application.create_key("app_key1")

      Metric.save(:service_id => @service.id, :id => @metric_id, :name => 'hits')

      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :day        => 100)

      Transactor.caching_disable

      12.times do |i|
        get '/transactions/authorize.xml', :provider_key => @provider_key,
                                         :app_id       => @application.id,
                                         :app_key      => app_key
        not_cached << last_response.body

        post '/transactions.xml',
            :provider_key => @provider_key,
            :transactions => {0 => {:app_id => @application.id, :usage => {'hits' => 10}}}

        Resque.run!


      end

    end  

    11.times do |i|
      assert_not_nil  cached[i]
      assert_equal    cached[i], not_cached[i]
      assert_not_equal  cached[i], cached[i-1] if i>0
      assert_not_equal  not_cached[i], not_cached[i-1] if i>0

      doc   = Nokogiri::XML(cached[i])
      assert_equal 'true', doc.at('status:root authorized').content

    end
  
    doc   = Nokogiri::XML(cached[11])
    assert_equal 'false', doc.at('status:root authorized').content
    doc   = Nokogiri::XML(not_cached[11])
    assert_equal 'false', doc.at('status:root authorized').content

    Transactor.caching_enable if caching_was_enabled
    
  end


  test 'check signature with versions' do 

    ## this test only makes sense if caching is enabled
    return unless Transactor.caching_enabled?  

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day        => 100)

    Timecop.freeze(Time.utc(2010, 5, 14)) do

        params = {:provider_key => @provider_key,
                  :app_id       => @application.id,
                  :usage        => {'hits' => 2}}

        key_version = Cache.signature(:authrep,params)

        get '/transactions/authrep.xml', params
        Resque.run!

        get '/transactions/authrep.xml', params
        Resque.run!
        
        version, ver_service, ver_application = @storage.mget(key_version,Service.storage_key(@service.id, :version),Application.storage_key(@service.id,@application.id,:version))
        current_version = "s:#{ver_service}/a:#{ver_application}"
        assert_equal version, current_version

        get '/transactions/authrep.xml', params
        Resque.run!

        version, ver_service, ver_application = @storage.mget(key_version,Service.storage_key(@service.id, :version),Application.storage_key(@service.id,@application.id,:version))
        current_version = "s:#{ver_service}/a:#{ver_application}"
        assert_equal version, current_version      

        ## now modify usage limit
        UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day        => 200)

        version, ver_service, ver_application = @storage.mget(key_version,Service.storage_key(@service.id, :version),Application.storage_key(@service.id,@application.id,:version))
        current_version = "s:#{ver_service}/a:#{ver_application}"
        assert_not_equal version, current_version

        get '/transactions/authrep.xml', params
        Resque.run!

        version, ver_service, ver_application = @storage.mget(key_version,Service.storage_key(@service.id, :version),Application.storage_key(@service.id,@application.id,:version))
        current_version = "s:#{ver_service}/a:#{ver_application}"
        assert_equal version, current_version

        Metric.save(:service_id => @service.id, :id => (@metric_id.to_i+1).to_s, :name => 'hits2')

        version, ver_service, ver_application = @storage.mget(key_version,Service.storage_key(@service.id, :version),Application.storage_key(@service.id,@application.id,:version))
        current_version = "s:#{ver_service}/a:#{ver_application}"
        assert_not_equal version, current_version

        get '/transactions/authrep.xml', params
        Resque.run!

        version, ver_service, ver_application = @storage.mget(key_version,Service.storage_key(@service.id, :version),Application.storage_key(@service.id,@application.id,:version))
        current_version = "s:#{ver_service}/a:#{ver_application}"
        assert_equal version, current_version
   
    end 

  end

  
end
