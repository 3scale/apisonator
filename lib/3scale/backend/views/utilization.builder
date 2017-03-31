xml.instruct!
xml.utilization do
  if @usage_reports.size > 0
    xml.max_utilization :value => @max_utilization

    if !@max_record.nil?
      xml.max_usage_report :period => @max_record.period, :metric_name => @max_record.metric_name, :max_value => @max_record.max_value, :current_value => @max_record.current_value
    end

    xml.usage_reports do
      @usage_reports.each do |item|
        xml.usage_report :period => item.period, :metric_name => item.metric_name, :max_value => item.max_value, :current_value => item.current_value
      end
    end

    xml.stats do
      @stats.each do |item|
        t,v = item.split(",")
        xml.data :time => t, :value => v
      end
    end
  end
end
