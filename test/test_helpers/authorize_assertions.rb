module TestHelpers
  module AuthorizeAssertions
    private

    include ThreeScale::Backend

    def assert_authorized
      assert_equal 200, last_response.status

      doc = Nokogiri::XML(last_response.body)
      assert_equal 'true', doc.at('status authorized').content
    end

    def assert_not_authorized(reason = nil)
      assert_equal 409, last_response.status

      doc = Nokogiri::XML(last_response.body)
      assert_equal 'false', doc.at('status authorized').content
      assert_equal reason,  doc.at('status reason').content if reason
    end

    def assert_not_usage_report
      doc = Nokogiri::XML(last_response.body)
      usage_reports = doc.at('usage_reports')
      assert_nil usage_reports
    end

    def assert_not_user_usage_report
      doc = Nokogiri::XML(last_response.body)
      usage_reports = doc.at('user_usage_reports')
      assert_nil usage_reports
    end

    def assert_usage_report(time, metric, period, current_value, max_value)
      doc = Nokogiri::XML(last_response.body)
      usage_reports = doc.at('usage_reports')
      assert_not_nil usage_reports

      metric = metric.to_s
      period = period.to_s
      obj = usage_reports.at("usage_report[metric = \"#{metric}\"][period = \"#{period}\"]")
      assert_not_nil obj

      if period=="eternity"
        assert_nil                                obj.at('period_start')
        assert_nil                                obj.at('period_end')
      else
        assert_equal Period::Boundary.start_of(period, time).strftime(TIME_FORMAT), obj.at('period_start').content
        assert_equal Period::Boundary.end_of(period, time).strftime(TIME_FORMAT), obj.at('period_end').content
      end
      assert_equal current_value.to_s,            obj.at('current_value').content
      assert_equal max_value.to_s,                obj.at('max_value').content
    end

    def assert_user_usage_report(time, metric, period, current_value, max_value)
      doc = Nokogiri::XML(last_response.body)
      usage_reports = doc.at('user_usage_reports')
      assert_not_nil usage_reports

      metric = metric.to_s
      period = period.to_s

      obj = usage_reports.at("usage_report[metric = \"#{metric}\"][period = \"#{period}\"]")
      assert_not_nil obj

      if period=="eternity"
        assert_nil                                obj.at('period_start')
        assert_nil                                obj.at('period_end')
      else
        assert_equal Period::Boundary.start_of(period, time).
          strftime(TIME_FORMAT), obj.at('period_start').content
        assert_equal Period::Boundary.end_of(period, time).
          strftime(TIME_FORMAT), obj.at('period_end').content
      end
      assert_equal current_value.to_s,            obj.at('current_value').content
      assert_equal max_value.to_s,                obj.at('max_value').content
    end

  end
end
