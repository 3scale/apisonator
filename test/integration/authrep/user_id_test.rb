require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AuthrepUserIdTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::StorageKeys


  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!

    setup_provider_fixtures

    @default_user_plan_id = next_id
    @default_user_plan_name = "user plan mobile"

    @service.user_registration_required = false
    @service.default_user_plan_name = @default_user_plan_name
    @service.default_user_plan_id = @default_user_plan_id
    @service.save!

    @application_with_users = Application.save(:service_id => @service.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id,
                                    :plan_name  => @plan_name,
                                    :user_required => true)

    @application_without_users = Application.save(:service_id => @service.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id,
                                    :plan_name  => @plan_name)

    @hits = Metric.save(:service_id => @service.id, :id => next_id, :name => 'hits')
    @foo = Metric.save(:service_id => @service.id, :id => next_id, :name => 'foo')


    @ul1 = UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @plan_id,
                    :metric_id  => @hits.id,
                    :day => 100)

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @default_user_plan_id,
                    :metric_id  => @hits.id,
                    :day => 20)

    UsageLimit.save(:service_id => @service.id,
                    :plan_id    => @default_user_plan_id,
                    :metric_id  => @foo.id,
                    :day => 10)


  end

   
  test 'application without end user required does not return user usage reports' do


    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_without_users.id,
                                     :usage        => {'hits' => 3}

    Resque.run!

    assert_equal 200, last_response.status
    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_not_nil day
    assert_equal '3', day.at('current_value').content
    usage_reports = doc.at('user_usage_reports')
    assert_nil usage_reports
    assert_nil doc.at('user_plan')

    last_doc = doc

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_without_users.id,
                                     :usage        => {'hits' => 0},
                                     :user_id      => "random user id"

    Resque.run!
    assert_equal 200, last_response.status
    doc = Nokogiri::XML(last_response.body)
    assert_equal last_doc.to_xml, doc.to_xml


  end

  test 'user usage report depends on the user_id, whereas usage report does not' do


    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_with_users.id,
                                     :usage        => {'hits' => 3},
                                     :user_id      => "user1"

    Resque.run!

    assert_equal 200, last_response.status
    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_not_nil day
    assert_equal '3', day.at('current_value').content
    usage_reports = doc.at('user_usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_not_nil day
    assert_equal '3', day.at('current_value').content
    day = usage_reports.at('usage_report[metric = "foo"][period = "day"]')
    assert_not_nil day
    assert_equal '0', day.at('current_value').content
    assert_equal @default_user_plan_name, doc.at('user_plan').content

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_with_users.id,
                                     :usage        => {'hits' => 3},
                                     :user_id      => "user1"

    Resque.run!

    assert_equal 200, last_response.status
    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_not_nil day
    assert_equal '6', day.at('current_value').content
    usage_reports = doc.at('user_usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_not_nil day
    assert_equal '6', day.at('current_value').content
    day = usage_reports.at('usage_report[metric = "foo"][period = "day"]')
    assert_not_nil day
    assert_equal '0', day.at('current_value').content
    assert_equal @default_user_plan_name, doc.at('user_plan').content

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_with_users.id,
                                     :usage        => {'hits' => 3},
                                     :user_id      => "user2"

    Resque.run!

    assert_equal 200, last_response.status
    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_not_nil day
    assert_equal '9', day.at('current_value').content
    usage_reports = doc.at('user_usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_not_nil day
    assert_equal '3', day.at('current_value').content
    day = usage_reports.at('usage_report[metric = "foo"][period = "day"]')
    assert_not_nil day
    assert_equal '0', day.at('current_value').content
    assert_equal @default_user_plan_name, doc.at('user_plan').content

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_with_users.id,
                                     :usage        => {'foo' => 3},
                                     :user_id      => "user3"

    Resque.run!

    assert_equal 200, last_response.status
    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_not_nil day
    assert_equal '9', day.at('current_value').content
    usage_reports = doc.at('user_usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_not_nil day
    assert_equal '0', day.at('current_value').content
    day = usage_reports.at('usage_report[metric = "foo"][period = "day"]')
    assert_not_nil day
    assert_equal '3', day.at('current_value').content
    assert_equal @default_user_plan_name, doc.at('user_plan').content



  end

  test 'user usage reports are across service, independant of application' do

    @application_with_users2 = Application.save(:service_id => @service.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id,
                                    :plan_name  => @plan_name,
                                    :user_required => true)

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_with_users.id,
                                     :usage        => {'hits' => 3},
                                     :user_id      => "user1"

    Resque.run!

    assert_equal 200, last_response.status
    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_not_nil day
    assert_equal '3', day.at('current_value').content
    usage_reports = doc.at('user_usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_not_nil day
    assert_equal '3', day.at('current_value').content
    day = usage_reports.at('usage_report[metric = "foo"][period = "day"]')
    assert_not_nil day
    assert_equal '0', day.at('current_value').content
    assert_equal @default_user_plan_name, doc.at('user_plan').content

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_with_users2.id,
                                     :usage        => {'hits' => 3},
                                     :user_id      => "user1"

    Resque.run!

    assert_equal 200, last_response.status
    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_not_nil day
    assert_equal '3', day.at('current_value').content
    usage_reports = doc.at('user_usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_not_nil day
    assert_equal '6', day.at('current_value').content
    day = usage_reports.at('usage_report[metric = "foo"][period = "day"]')
    assert_not_nil day
    assert_equal '0', day.at('current_value').content
    assert_equal @default_user_plan_name, doc.at('user_plan').content

  end

  test 'application with users required fails if user_id is not passed or not valid' do
    
    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_with_users.id,
                                     :usage        => {'hits' => 3}
    Resque.run!

    assert_equal 403, last_response.status
    doc = Nokogiri::XML(last_response.body)
    assert_equal 'user_not_defined', doc.at('error')[:code]

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_with_users.id,
                                     :usage        => {'hits' => 3},
                                     :user_id      => ""
    Resque.run!

    assert_equal 403, last_response.status
    doc = Nokogiri::XML(last_response.body)
    assert_equal 'user_not_defined', doc.at('error')[:code]

    ## watch out, "   " could be a valid user_id

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_with_users.id,
                                     :usage        => {'hits' => 3},
                                     :user_id      => nil
    Resque.run!

    assert_equal 403, last_response.status
    doc = Nokogiri::XML(last_response.body)
    assert_equal 'user_not_defined', doc.at('error')[:code]

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_with_users.id,
                                     :usage        => {'hits' => 3},
                                     :user_id      => {}
    Resque.run!

    assert_equal 403, last_response.status
    doc = Nokogiri::XML(last_response.body)
    assert_equal 'user_not_defined', doc.at('error')[:code]

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_with_users.id,
                                     :usage        => {'hits' => 3},
                                     :user_id      => {'foo' => 'bar'}
    Resque.run!

    assert_equal 403, last_response.status
    doc = Nokogiri::XML(last_response.body)
    assert_equal 'user_not_defined', doc.at('error')[:code]

    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_with_users.id,
                                     :usage        => {'hits' => 3},
                                     :user_id      => ['bla', 'foo']
    Resque.run!

    assert_equal 403, last_response.status
    doc = Nokogiri::XML(last_response.body)
    assert_equal 'user_not_defined', doc.at('error')[:code]

    ## all number gets treated as string in the backend, it's ok
    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_with_users.id,
                                     :usage        => {'hits' => 3},
                                     :user_id      => 11111
    Resque.run!

    assert_equal 200, last_response.status
    doc = Nokogiri::XML(last_response.body)
    
  end

  test 'user plans does not need to have limits' do

    user = User.load_or_create!(@service,"user1") 
    assert_equal @default_user_plan_id, user.plan_id
    assert_equal @default_user_plan_name, user.plan_name

    new_user_plan_id = next_id
    user.plan_id = new_user_plan_id
    user.plan_name = "new name of user plan"
    user.save

    user = User.load_or_create!(@service,"user1") 
    assert_equal new_user_plan_id, user.plan_id
    assert_equal "new name of user plan", user.plan_name


    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_with_users.id,
                                     :usage        => {'hits' => 3},
                                     :user_id      => "user1"
    Resque.run!

    assert_equal 200, last_response.status
    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_not_nil day
    assert_equal '3', day.at('current_value').content
    usage_reports = doc.at('user_usage_reports')
    assert_nil usage_reports
    assert_equal "new name of user plan", doc.at('user_plan').content

    ## but that does not affect other users
    get '/transactions/authrep.xml', :provider_key => @provider_key,
                                     :app_id       => @application_with_users.id,
                                     :usage        => {'hits' => 3},
                                     :user_id      => "user2"

    Resque.run!
    assert_equal 200, last_response.status
    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_not_nil day
    assert_equal '6', day.at('current_value').content
    usage_reports = doc.at('user_usage_reports')
    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')
    assert_not_nil day
    assert_equal '3', day.at('current_value').content
    day = usage_reports.at('usage_report[metric = "foo"][period = "day"]')
    assert_not_nil day
    assert_equal '0', day.at('current_value').content
    assert_equal @default_user_plan_name, doc.at('user_plan').content


  end




end


