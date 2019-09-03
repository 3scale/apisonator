require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AuthrepMultiLevelHierarchyTest < Test::Unit::TestCase
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::AuthRep
  include TestHelpers::Extensions
  include TestHelpers::MetricsHierarchy

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!
    Memoizer.reset!

    @test_setup = setup_service_with_metric_hierarchy(3, oauth: true)
  end

  test_authrep 'denies when limits exceeded on an intermediate metric of the hierarchy' do |e|
    intermediate_metric = @test_setup[:metrics][1]
    bottom_metric = @test_setup[:metrics].last

    Transactor.report(
        @test_setup[:provider_key],
        @test_setup[:service_id],
        0 => { app_id: @test_setup[:app_id],
               usage: { intermediate_metric[:name] => intermediate_metric[:limit] } }
    )

    Resque.run!

    get e,
        provider_key: @test_setup[:provider_key],
        service_id: @test_setup[:service_id],
        app_id: @test_setup[:app_id],
        usage: { bottom_metric[:name] => 1 }

    Resque.run!

    assert_not_authorized 'usage limits are exceeded'
  end

  test_authrep 'denies when limits exceeded on the metric at the top of the hierarchy' do |e|
    top_metric = @test_setup[:metrics].first
    bottom_metric = @test_setup[:metrics].last

    Transactor.report(
      @test_setup[:provider_key],
      @test_setup[:service_id],
      0 => { app_id: @test_setup[:app_id],
             usage: { top_metric[:name] => top_metric[:limit] } }
    )

    Resque.run!

    get e,
        provider_key: @test_setup[:provider_key],
        service_id: @test_setup[:service_id],
        app_id: @test_setup[:app_id],
        usage: { bottom_metric[:name] => 1 }

    Resque.run!

    assert_not_authorized 'usage limits are exceeded'
  end

  test_authrep 'shows the correct current value for all the metrics in the hierarchy' do |e|
    bottom_metric = @test_setup[:metrics].last

    get e,
        provider_key: @test_setup[:provider_key],
        service_id: @test_setup[:service_id],
        app_id: @test_setup[:app_id],
        usage: { bottom_metric[:name] => 1 }

    Resque.run!

    metric_names = @test_setup[:metrics].map { |metric| metric[:name] }
    xml_usage_reports = Nokogiri::XML(last_response.body).at('usage_reports')

    metric_current_values = metric_names.map do |name|
      xml_usage_reports.at("usage_report[metric = \"#{name}\"]")
                       .at("current_value")
                       .content
                       .to_i
    end

    assert_true(metric_current_values.all?{ |val| val == 1 })
  end

  test_authrep 'when authorized, propagates the reports to all the levels in the hierarchy' do |e|
    bottom_metric = @test_setup[:metrics].last

    get e,
        provider_key: @test_setup[:provider_key],
        service_id: @test_setup[:service_id],
        app_id: @test_setup[:app_id],
        usage: { bottom_metric[:name] => 1 }

    Resque.run!

    app = Application.load!(@test_setup[:service_id], @test_setup[:app_id])
    usages = Usage.application_usage(app, Time.now)[Period::Day]
    metric_ids = @test_setup[:metrics].map { |metric| metric[:id] }
    all_increased = metric_ids.all? { |metric_id| usages[metric_id] == 1 }

    assert_true all_increased
  end

  test_authrep 'response includes correct hierarchy extension info when n_levels > 2' do |e|
    get e,
        {
          provider_key: @test_setup[:provider_key],
          service_id: @test_setup[:service_id],
          app_id: @test_setup[:app_id],
        },
        'HTTP_3SCALE_OPTIONS' => Extensions::HIERARCHY

    Resque.run!

    xml_resp = Nokogiri::XML(last_response.body)
    children_xml_correct = @test_setup[:metrics].each_cons(2).all? do |parent, child|
      children_resp = extract_children_from_resp(xml_resp, parent[:name])
      children_resp == [child[:name]]
    end

    assert_true children_xml_correct
  end
end
