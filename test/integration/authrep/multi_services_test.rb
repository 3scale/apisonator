require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AuthrepMultiServicesTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::StorageKeys

  include TestHelpers::AuthRep

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!
    Memoizer.reset!

    setup_oauth_provider_fixtures_multiple_services

    @application_1 = Application.save(:service_id => @service_1.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id_1,
                                    :plan_name  => @plan_name_1)

    @application_2 = Application.save(:service_id => @service_2.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id_2,
                                    :plan_name  => @plan_name_2)

    @application_3 = Application.save(:service_id => @service_3.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id_3,
                                    :plan_name  => @plan_name_3)

    @metric_id_1 = next_id
    Metric.save(:service_id => @service_1.id, :id => @metric_id_1, :name => 'hits')

    @metric_id_2 = next_id
    Metric.save(:service_id => @service_2.id, :id => @metric_id_2, :name => 'hits')

    @metric_id_3 = next_id
    Metric.save(:service_id => @service_3.id, :id => @metric_id_3, :name => 'hits')

    UsageLimit.save(:service_id => @service_1.id,
                    :plan_id    => @plan_id_1,
                    :metric_id  => @metric_id_1,
                    :day => 100)

    UsageLimit.save(:service_id => @service_2.id,
                    :plan_id    => @plan_id_2,
                    :metric_id  => @metric_id_2,
                    :day => 100)

    UsageLimit.save(:service_id => @service_3.id,
                    :plan_id    => @plan_id_3,
                    :metric_id  => @metric_id_3,
                    :day => 100)
  end

  test_authrep 'provider key with multiple services, check that call to authrep (most coverage) works with explicit/implicit service ids' do |e|
    get e, :provider_key => @provider_key,
           :app_id       => @application_3.id,
           :service_id   => @service_3.id,
           :usage        => {'hits' => 3}
    Resque.run!

    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')

    assert_not_nil usage_reports

    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

    assert_not_nil day
    assert_equal '3', day.at('current_value').content
    assert_equal 3, @storage.get(application_key(@service_3.id,
                                                 @application_3.id,
                                                 @metric_id_3,
                                                 :month, Time.now.getutc.strftime('%Y%m01'))).to_i

    get e, :provider_key => @provider_key,
           :app_id       => @application_2.id,
           :service_id   => @service_2.id,
           :usage        => {'hits' => 2}
    Resque.run!

    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')

    assert_not_nil usage_reports

    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

    assert_not_nil day
    assert_equal '2', day.at('current_value').content
    assert_equal 2, @storage.get(application_key(@service_2.id,
                                                 @application_2.id,
                                                 @metric_id_2,
                                                 :month, Time.now.getutc.strftime('%Y%m01'))).to_i

    get e, :provider_key => @provider_key,
           :app_id       => @application_1.id,
           :service_id   => @service_1.id,
           :usage        => {'hits' => 1}
    Resque.run!

    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')

    assert_not_nil usage_reports

    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

    assert_not_nil day
    assert_equal '1', day.at('current_value').content
    assert_equal 1, @storage.get(application_key(@service_1.id,
                                                 @application_1.id,
                                                 @metric_id_1,
                                                 :month, Time.now.getutc.strftime('%Y%m01'))).to_i

    ## now without explicit service_id
    get e, :provider_key => @provider_key,
           :app_id       => @application_1.id,
           :usage        => {'hits' => 10}
    Resque.run!

    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')

    assert_not_nil usage_reports
    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

    assert_not_nil day
    assert_equal '11', day.at('current_value').content
    assert_equal 11, @storage.get(application_key(@service_1.id,
                                                  @application_1.id,
                                                  @metric_id_1,
                                                  :month, Time.now.getutc.strftime('%Y%m01'))).to_i
  end

  test_authrep 'provider key with multiple services, check that call to authrep (most coverage) works with explicit/implicit service ids while changing the default service' do |e|
    get e, :provider_key => @provider_key,
           :app_id       => @application_2.id,
           :service_id   => @service_2.id,
           :usage        => {'hits' => 2}
    Resque.run!

    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')

    assert_not_nil usage_reports

    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

    assert_not_nil day
    assert_equal '2', day.at('current_value').content
    assert_equal 2, @storage.get(application_key(@service_2.id,
                                                 @application_2.id,
                                                 @metric_id_2,
                                                 :month, Time.now.getutc.strftime('%Y%m01'))).to_i

    get e, :provider_key => @provider_key,
           :app_id       => @application_1.id,
           :service_id   => @service_1.id,
           :usage        => {'hits' => 1}
    Resque.run!

    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')

    assert_not_nil usage_reports

    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

    assert_not_nil day
    assert_equal '1', day.at('current_value').content
    assert_equal 1, @storage.get(application_key(@service_1.id,
                                                 @application_1.id,
                                                 @metric_id_1,
                                                 :month, Time.now.getutc.strftime('%Y%m01'))).to_i

    ## now without explicit service_id
    get e, :provider_key => @provider_key,
           :app_id       => @application_1.id,
           :usage        => {'hits' => 10}
    Resque.run!

    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')

    assert_not_nil usage_reports

    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

    assert_not_nil day
    assert_equal '11', day.at('current_value').content
    assert_equal 11, @storage.get(application_key(@service_1.id,
                                                  @application_1.id,
                                                  @metric_id_1,
                                                  :month, Time.now.getutc.strftime('%Y%m01'))).to_i

    ## now, change the default service id to be the second one
    Memoizer.reset!

    @service_2.default_service = true
    @service_2.save!

    get e, :provider_key => @provider_key,
           :app_id       => @application_2.id,
           :usage        => {'hits' => 10}
    Resque.run!

    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')

    assert_not_nil usage_reports

    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

    assert_not_nil day
    assert_equal '12', day.at('current_value').content
    assert_equal 12, @storage.get(application_key(@service_2.id,
                                                  @application_2.id,
                                                  @metric_id_2,
                                                  :month, Time.now.getutc.strftime('%Y%m01'))).to_i

    assert_equal 11, @storage.get(application_key(@service_1.id,
                                                  @application_1.id,
                                                  @metric_id_1,
                                                  :month, Time.now.getutc.strftime('%Y%m01'))).to_i

    ## more calls
    get e, :provider_key => @provider_key,
           :app_id       => @application_1.id,
           :service_id   => @service_1.id,
           :usage        => {'hits' => 20}
    Resque.run!

    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')

    assert_not_nil usage_reports

    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

    assert_not_nil day
    assert_equal '31', day.at('current_value').content
    assert_equal 31, @storage.get(application_key(@service_1.id,
                                                 @application_1.id,
                                                 @metric_id_1,
                                                 :month, Time.now.getutc.strftime('%Y%m01'))).to_i

    get e, :provider_key => @provider_key,
           :app_id       => @application_2.id,
           :service_id   => @service_2.id,
           :usage        => {'hits' => 20}
    Resque.run!

    assert_equal 200, last_response.status

    doc = Nokogiri::XML(last_response.body)
    usage_reports = doc.at('usage_reports')

    assert_not_nil usage_reports

    day = usage_reports.at('usage_report[metric = "hits"][period = "day"]')

    assert_not_nil day
    assert_equal '32', day.at('current_value').content
    assert_equal 32, @storage.get(application_key(@service_2.id,
                                                 @application_2.id,
                                                 @metric_id_2,
                                                 :month, Time.now.getutc.strftime('%Y%m01'))).to_i
  end

  test_authrep 'provider_key needs to be checked regardless if the service_id is correct' do |e|
    get e, :provider_key => 'fakeproviderkey',
           :app_id       => @application_1.id,
           :usage        => {'hits' => 2}
    Resque.run!

    assert_equal 403, last_response.status

    doc = Nokogiri::XML(last_response.body)
    error = doc.at('error:root')

    assert_not_nil error
    assert_equal 'provider_key_invalid_or_service_missing', error['code']

    get e, :provider_key => 'fakeproviderkey',
           :service_id   => @service_1.id,
           :app_id       => @application_1.id,
           :usage        => {'hits' => 1}
    Resque.run!

    assert_equal 403, last_response.status
    doc = Nokogiri::XML(last_response.body)
    error = doc.at('error:root')

    assert_not_nil error
    assert_equal 'provider_key_invalid', error['code']

    get e, :provider_key => 'fakeproviderkey',
           :service_id   => @service_2.id,
           :app_id       => @application_2.id,
           :usage        => {'hits' => 2}
    Resque.run!

    assert_equal 403, last_response.status
    doc = Nokogiri::XML(last_response.body)
    error = doc.at('error:root')

    assert_not_nil error
    assert_equal 'provider_key_invalid', error['code']
  end

  test_authrep 'testing that the app_id matches the service that is default service' do |e|
    ## user want to access the service_2 but forget to add service_id, and app_id == @application_2.id does not
    ## exists for the service_1

    get e, :provider_key => @provider_key,
           :app_id       => @application_2.id,
           :usage        => {'hits' => 2}
    Resque.run!

    assert_equal 404, last_response.status

    doc = Nokogiri::XML(last_response.body)
    error = doc.at('error:root')

    assert_not_nil error
    assert_equal 'application_not_found', error['code']
  end

  test_authrep 'when service_id is not valid there is an error no matter if the provider key is valid' do |e|
    get e, :provider_key => @provider_key,
           :service_id   => @service_2.id << '666',
           :app_id       => @application_2.id,
           :usage        => {'hits' => 2}
    Resque.run!

    assert_equal 403, last_response.status

    doc = Nokogiri::XML(last_response.body)
    error = doc.at('error:root')

    assert_not_nil error
    assert_equal 'service_id_invalid', error['code']

    get e, :provider_key => @provider_key,
           :service_id   => @service_1.id << '666',
           :app_id       => @application_1.id,
           :usage        => {'hits' => 2}
    Resque.run!

    assert_equal 403, last_response.status

    doc = Nokogiri::XML(last_response.body)
    error = doc.at('error:root')

    assert_not_nil error
    assert_equal 'service_id_invalid', error['code']
  end
end
