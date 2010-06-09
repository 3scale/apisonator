require File.dirname(__FILE__) + '/../../test_helper'

module Serializers
  class StatusV1_1Test < Test::Unit::TestCase
    include TestHelpers::EventMachine

    def setup
      Storage.instance(true).flushdb
      
      @service_id  = 1001
      @plan_id     = 2001
      @contract_id = 3001
      @metric_id   = 4001

      @contract = Contract.new(:service_id => @service_id,
                               :id         => @contract_id,
                               :plan_id    => @plan_id,
                               :plan_name  => 'awesome')

      Metric.save(:service_id => @service_id, :id => @metric_id, :name => 'foos')
    end

    def test_serialize
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month      => 2000)

      time = Time.utc(2010, 5, 17, 12, 42)
      usage = {:month => {@metric_id.to_s => 429}}

      Timecop.freeze(time) do
        status = Transactor::Status.new(@contract, usage)
        xml    = Serializers::StatusV1_1.serialize(status)
        doc    = Nokogiri::XML(xml)
        
        root = doc.at('status:root')        
        assert_not_nil root

        assert_equal 'true',    root.at('authorized').content
        assert_equal 'awesome', root.at('plan').content

        usage_reports = root.at('usage_reports')
        assert_not_nil usage_reports

        report = usage_reports.at('usage_report[metric = "foos"][period = "month"]')
        assert_not_nil report
        assert_equal '2010-05-01 00:00:00', report.at('period_start').content
        assert_equal '2010-06-01 00:00:00', report.at('period_end').content
        assert_equal '429',                 report.at('current_value').content
        assert_equal '2000',                report.at('max_value').content
      end
    end

    def test_does_not_serialize_empty_usage_reports
      usage = {:month => {@metric_id.to_s => 429}}

      status = Transactor::Status.new(@contract, usage)
      xml    = Serializers::StatusV1_1.serialize(status)
      doc    = Nokogiri::XML(xml)

      assert_nil doc.at('status usage_reports')        
    end

    def test_serialize_rejected_status
      usage = {:month => {@metric_id.to_s => 429}}

      status = Transactor::Status.new(@contract, usage)
      status.reject!('user.inactive_contract')

      xml = Serializers::StatusV1_1.serialize(status)
      doc = Nokogiri::XML(xml)

      assert_equal 'false',                  doc.at('status authorized').content
      assert_equal 'contract is not active', doc.at('status reason').content
    end

    def test_serialize_marks_exceeded_usage_reports
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month => 2000, :day => 100)

      usage = {:month => {@metric_id.to_s => 1420},
               :day   => {@metric_id.to_s => 122}}

      status = Transactor::Status.new(@contract, usage)
      xml    = Serializers::StatusV1_1.serialize(status)
      doc    = Nokogiri::XML(xml)
     
      month  = doc.at('usage_report[metric = "foos"][period = "month"]')
      day    = doc.at('usage_report[metric = "foos"][period = "day"]')

      assert_nil           month['exceeded']
      assert_equal 'true', day['exceeded']
    end
  end
end
