require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Transactor
  class StatusTest < Test::Unit::TestCase
    include TestHelpers::StorageKeys
    include TestHelpers::Sequences

    def setup
      @storage = Storage.instance(true)
      @storage.flushdb

      @service_id     = next_id
      @plan_id        = next_id
      @application_id = next_id
      @metric_id      = next_id

      # use names that NEED escaping in our output format
      @plan_name      = 'awesome & co. <needs> "escaping"'
      # MT _SHOULD_ guarantee this doesn't need XML escaping for attributes or text
      @metric_name    = 'foos'

      @application    = Application.new(:service_id => @service_id,
                                        :id         => next_id,
                                        :plan_id    => @plan_id,
                                        :plan_name  => @plan_name)

      @application_w_keys = Application.new(:service_id => @service_id,
                                            :id         => next_id,
                                            :plan_id    => @plan_id,
                                            :plan_name  => @plan_name)

      @keys = 3.times.map { |i| "key_#{i}" }

      @keys.each do |k|
        @application_w_keys.create_key k
      end

      Metric.save(:service_id => @service_id,
                  :id         => @metric_id,
                  :name       => @metric_name)
    end

    test 'status contains usage reports' do
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month      => 2000)

      time = Time.utc(2010, 5, 17, 12, 42)
      usage = {:month => {@metric_id.to_s => 429}}

      Timecop.freeze(time) do
        status = Transactor::Status.new(service_id: @service_id,
                                        application: @application,
                                        values: usage)

        assert_equal 1, status.application_usage_reports.count

        report = status.application_usage_reports.first
        assert_equal :month,               report.period.to_sym
        assert_equal @metric_name,         report.metric_name
        assert_equal Time.utc(2010, 5, 1), report.period.start
        assert_equal Time.utc(2010, 6, 1), report.period.finish
        assert_equal 2000,                 report.max_value
        assert_equal 429,                  report.current_value
      end
    end

    test 'does not contain usage reports that have an empty metric name' do
      metric = Metric.save(:service_id => @service_id,
                           :id         => @metric_id,
                           :name       => 'a_metric_name')

      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => metric.id,
                      :month      => 2000)

      Metric.delete(@service_id, metric.id)
      # We do not delete the usage limit that affects the metric

      status = Transactor::Status.new(service_id: @service_id,
                                      application: @application)
      assert_equal 0, status.application_usage_reports.size
    end

    test 'usage report is marked as exceeded when current value is greater than max value' do
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month      => 2000)

      usage  = {:month => {@metric_id.to_s => 2002}}
      status = Transactor::Status.new(service_id: @service_id,
                                      application: @application,
                                      values: usage)

      assert status.application_usage_reports.first.exceeded?
    end

    test 'usage report is not marked as exceeded when current value is less than max value' do
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month      => 2000)

      usage  = {:month => {@metric_id.to_s => 1999}}
      status = Transactor::Status.new(service_id: @service_id,
                                      application: @application,
                                      values: usage)

      assert !status.application_usage_reports.first.exceeded?
    end

    test 'usage report is not marked as exceeded when current value equals max value' do
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month      => 2000)

      usage  = {:month => {@metric_id.to_s => 2000}}
      status = Transactor::Status.new(service_id: @service_id,
                                      application: @application,
                                      values: usage)

      assert !status.application_usage_reports.first.exceeded?
    end

    test '#authorized? returns true by default' do
      status = Transactor::Status.new(service_id: @service_id,
                                      application: @application)
      assert status.authorized?
    end

    test '#authorized? returns false when rejected' do
      status = Transactor::Status.new(service_id: @service_id,
                                      application: @application)
      status.reject!(ApplicationNotActive.new)

      assert !status.authorized?
    end

    test 'status contains rejection reason when rejected' do
      status = Transactor::Status.new(service_id: @service_id,
                                      application: @application)
      status.reject!(ApplicationNotActive.new)

      assert_equal 'application_not_active',    status.rejection_reason_code
      assert_equal 'application is not active', status.rejection_reason_text
    end

    test 'rejection reason can be set only once' do
      status = Transactor::Status.new(service_id: @service_id,
                                      application: @application)
      status.reject!(ApplicationNotActive.new)
      status.reject!(LimitsExceeded.new)

      assert_equal 'application_not_active', status.rejection_reason_code
    end

    test '#to_xml' do
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month      => 2000)

      time = Time.utc(2010, 5, 17, 12, 42)
      usage = {:month => {@metric_id.to_s => 429}}

      Timecop.freeze(time) do
        xml = Transactor::Status.new(service_id: @service_id,
                                     application: @application,
                                     values: usage).to_xml

        doc = Nokogiri::XML(xml)

        root = doc.at('status:root')
        assert_not_nil root

        assert_equal 'true',     root.at('authorized').content
        assert_not_nil root.at('plan')
        assert_equal @plan_name, root.at('plan').content

        usage_reports = root.at('usage_reports')
        assert_not_nil usage_reports

        # XPath and CSS selectors just won't work in Nokogiri with doubly-quoted
        # strings for attributes.
        # See https://groups.google.com/forum/#!topic/nokogiri-talk/6stziv8GcJM
        report = usage_reports.search('usage_report').find do |node|
          node['metric'] == @metric_name && node['period'] == 'month'
        end
        assert_not_nil report
        assert_equal '2010-05-01 00:00:00 +0000', report.at('period_start').content
        assert_equal '2010-06-01 00:00:00 +0000', report.at('period_end').content
        assert_equal '429',                       report.at('current_value').content
        assert_equal '2000',                      report.at('max_value').content
      end
    end

    test '#to_xml does not serialize empty usage reports' do
      usage  = {:month => {@metric_id.to_s => 429}}
      status = Transactor::Status.new(service_id: @service_id,
                                      application: @application,
                                      values: usage)

      doc = Nokogiri::XML(status.to_xml)

      assert_nil doc.at('status usage_reports')
    end

    test '#to_xml on rejected status' do
      usage = {:month => {@metric_id.to_s => 429}}

      status = Transactor::Status.new(service_id: @service_id,
                                      application: @application,
                                      values: usage)
      status.reject!(ApplicationNotActive.new)

      doc = Nokogiri::XML(status.to_xml)

      assert_equal 'false',                     doc.at('status authorized').content
      assert_equal 'application is not active', doc.at('status reason').content
    end

    test '#to_xml marks exceeded usage reports' do
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month => 2000, :day => 100)

      usage  = {:month => {@metric_id.to_s => 1420},
                :day   => {@metric_id.to_s => 122}}
      status = Transactor::Status.new(service_id: @service_id,
                                      application: @application,
                                      values: usage)

      doc = Nokogiri::XML(status.to_xml)

      nodes = doc.search('usage_report').find_all do |node|
        node['metric'] == @metric_name
      end
      month  = nodes.find { |n| n['period'] == 'month' }
      day    = nodes.find { |n| n['period'] == 'day' }

      assert_not_nil       month
      assert_not_nil       day
      assert_nil           month['exceeded']
      assert_equal 'true', day['exceeded']
    end

    test '#to_xml shows the application id when OAuth is used' do
      usage  = {:month => {@metric_id.to_s => 429}}
      status = Transactor::Status.new(service_id: @service_id,
                                      application: @application,
                                      values: usage,
                                      oauth: true)

      doc = Nokogiri::XML(status.to_xml)

      assert_equal @application.id,  doc.at('status application id').content
    end

    test '#to_xml lists application keys section when list_app_keys ext is enabled' do
      usage  = {:month => {@metric_id.to_s => 429}}
      status = Transactor::Status.new(service_id: @service_id,
                                      application: @application,
                                      list_app_keys: 1,
                                      values: usage,
                                      oauth: true)

      doc = Nokogiri::XML(status.to_xml)

      app_keys = doc.at 'app_keys'
      assert_not_nil app_keys
      assert_equal @application.id, app_keys['app']
      assert_equal @service_id, app_keys['svc']
      keys = doc.search 'app_keys key'
      assert_empty keys
    end

    test '#to_xml lists application keys section with keys when list_app_keys ext is enabled' do
      usage  = {:month => {@metric_id.to_s => 429}}
      status = Transactor::Status.new(service_id: @service_id,
                                      application: @application_w_keys,
                                      list_app_keys: 1,
                                      values: usage,
                                      oauth: true)

      doc = Nokogiri::XML(status.to_xml)

      app_keys = doc.at 'app_keys'
      assert_not_nil app_keys
      assert_equal @application_w_keys.id, app_keys['app']
      assert_equal @service_id, app_keys['svc']
      keys = doc.search('app_keys key').map { |k| k['id'] }
      assert_not_empty keys
      assert_equal @keys.sort, keys.sort
    end
  end
end
