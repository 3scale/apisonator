require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AuthrepCacheTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::StorageKeys

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!

    setup_provider_fixtures

    @application = Application.save(:service_id => @service.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id,
                                    :plan_name  => @plan_name)

    @metric_id = next_id
    Metric.save(:service_id => @service.id, :id => @metric_id, :name => 'hits')
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
                                        
    doc   = Nokogiri::XML(last_response.body)
    assert_equal 'false', doc.at('status:root authorized').content
    assert_equal 409, last_response.status

    ## checking that they can be remove and then it's fine
    
    @application.delete_key("app_key1")
    @application.delete_key("app_key2")


    get '/transactions/authorize.xml',    :provider_key => @provider_key,
                                          :app_id       => @application.id
   
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


    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day        => 100)

    Timecop.freeze(Time.utc(2010, 5, 14)) do

      10.times do |i|
        get '/transactions/authrep.xml', :provider_key => @provider_key,
                                         :app_id       => @application.id,
                                         :usage        => {'hits' => 2}
        cached << last_response.body


        get '/transactions/authrep.xml', :provider_key => @provider_key,
                                         :app_id       => @application.id,
                                         :usage        => {'hits' => 2},
                                         :no_caching   => true
        not_cached << last_response.body

        Resque.run!
      end

    end    

    10.times do |i|
      assert_not_nil  cached[i-1]
      assert_equal    cached[i-1], not_cached[i-1]
      assert_not_equal  cached[i-1], cached[i-2] if i>1
      assert_not_equal  not_cached[i-1], not_cached[i-2] if i>1
    end
    
  end

  test 'check signature with versions' do 

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
