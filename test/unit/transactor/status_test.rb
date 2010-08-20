require File.dirname(__FILE__) + '/../../test_helper'

module Transactor
  class StatusTest < Test::Unit::TestCase
    include TestHelpers::StorageKeys

    def setup
      @storage = Storage.instance(true)
      @storage.flushdb
      
      @service_id     = 1001
      @plan_id        = 2001
      @application_id = 3001
      @metric_id      = 4001

      @plan_name      = 'awesome'

      @application    = Application.new(:service_id => @service_id,
                                        :id         => @application_id,
                                        :plan_id    => @plan_id,
                                        :plan_name  => @plan_name)

      Metric.save(:service_id => @service_id, 
                  :id         => @metric_id, 
                  :name       => 'foos')
    end

    def test_status_contains_usage_reports
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month      => 2000)

      time = Time.utc(2010, 5, 17, 12, 42)
      usage = {:month => {@metric_id.to_s => 429}}

      Timecop.freeze(time) do
        status = Transactor::Status.new(@application, usage)

        assert_equal 1, status.usage_reports.count

        report = status.usage_reports.first
        assert_equal :month,               report.period
        assert_equal 'foos',               report.metric_name
        assert_equal Time.utc(2010, 5, 1), report.period_start
        assert_equal Time.utc(2010, 6, 1), report.period_end
        assert_equal 2000,                 report.max_value
        assert_equal 429,                  report.current_value
      end
    end

    def test_usage_report_is_marked_as_exceeded_when_current_value_is_greater_than_max_value
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month      => 2000)

      usage  = {:month => {@metric_id.to_s => 2002}}
      status = Transactor::Status.new(@application, usage)

      assert status.usage_reports.first.exceeded?
    end
    
    def test_usage_report_is_not_marked_as_exceeded_when_current_value_is_less_than_max_value
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month      => 2000)

      usage  = {:month => {@metric_id.to_s => 1999}}
      status = Transactor::Status.new(@application, usage)

      assert !status.usage_reports.first.exceeded?
    end
    
    def test_usage_report_is_not_marked_as_exceeded_when_current_value_equals_max_value
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month      => 2000)

      usage  = {:month => {@metric_id.to_s => 2000}}
      status = Transactor::Status.new(@application, usage)

      assert !status.usage_reports.first.exceeded?
    end

    def test_status_is_authorized_by_default
      status = Transactor::Status.new(@application, {})
      assert status.authorized?
    end

    def test_status_is_not_authorized_when_rejected
      status = Transactor::Status.new(@application, {})
      status.reject!(ApplicationNotActive.new)

      assert !status.authorized?
    end
    
    def test_status_contains_rejection_reason_when_rejected
      status = Transactor::Status.new(@application, {})
      status.reject!(ApplicationNotActive.new)

      assert_equal 'application_not_active',    status.rejection_reason_code
      assert_equal 'application is not active', status.rejection_reason_text
    end

    def test_rejection_reason_can_be_set_only_once
      status = Transactor::Status.new(@application, {})
      status.reject!(ApplicationNotActive.new)
      status.reject!(LimitsExceeded.new)
      
      assert_equal 'application_not_active', status.rejection_reason_code
    end

    def test_reject_unless_bang_rejects_when_the_block_evaluates_to_false
      status = Transactor::Status.new(@application, {})
      status.reject_unless!(ApplicationNotActive.new) { false }

      assert !status.authorized?
    end
    
    def test_reject_unless_bang_does_no_reject_when_the_block_evaluates_to_true
      status = Transactor::Status.new(@application, {})
      status.reject_unless!(ApplicationNotActive.new) { true }

      assert status.authorized?
    end
    
    def test_reject_unless_bang_does_no_evaluate_the_block_if_already_rejected
      status = Transactor::Status.new(@application, {})
      status.reject!(ApplicationNotActive.new)

      evaluated = false

      status.reject_unless!(LimitsExceeded.new) { evaluated = true; false }

      assert !evaluated
    end

    def test_to_xml
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month      => 2000)

      time = Time.utc(2010, 5, 17, 12, 42)
      usage = {:month => {@metric_id.to_s => 429}}

      Timecop.freeze(time) do
        xml = Transactor::Status.new(@application, usage).to_xml
        doc = Nokogiri::XML(xml)
        
        root = doc.at('status:root')        
        assert_not_nil root

        assert_equal 'true',     root.at('authorized').content
        assert_equal @plan_name, root.at('plan').content

        usage_reports = root.at('usage_reports')
        assert_not_nil usage_reports

        report = usage_reports.at('usage_report[metric = "foos"][period = "month"]')
        assert_not_nil report
        assert_equal '2010-05-01 00:00:00 +0000', report.at('period_start').content
        assert_equal '2010-06-01 00:00:00 +0000', report.at('period_end').content
        assert_equal '429',                       report.at('current_value').content
        assert_equal '2000',                      report.at('max_value').content
      end
    end

    def test_does_not_serialize_empty_usage_reports
      usage = {:month => {@metric_id.to_s => 429}}

      xml = Transactor::Status.new(@application, usage).to_xml
      doc = Nokogiri::XML(xml)

      assert_nil doc.at('status usage_reports')        
    end

    def test_serialize_rejected_status
      usage = {:month => {@metric_id.to_s => 429}}

      status = Transactor::Status.new(@application, usage)
      status.reject!(ApplicationNotActive.new)

      doc = Nokogiri::XML(status.to_xml)

      assert_equal 'false',                     doc.at('status authorized').content
      assert_equal 'application is not active', doc.at('status reason').content
    end

    def test_serialize_marks_exceeded_usage_reports
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month => 2000, :day => 100)

      usage = {:month => {@metric_id.to_s => 1420},
               :day   => {@metric_id.to_s => 122}}

      xml = Transactor::Status.new(@application, usage).to_xml
      doc = Nokogiri::XML(xml)
     
      month  = doc.at('usage_report[metric = "foos"][period = "month"]')
      day    = doc.at('usage_report[metric = "foos"][period = "day"]')

      assert_nil           month['exceeded']
      assert_equal 'true', day['exceeded']
    end
  end
end
