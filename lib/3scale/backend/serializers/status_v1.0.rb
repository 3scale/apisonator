module ThreeScale
  module Backend
    module Serializers
      module StatusV1_0
        def self.serialize(status, options = {})
          xml = Builder::XmlMarkup.new
          xml.instruct! unless options[:skip_instruct]

          if status.authorized?
            xml.status do
              xml.plan status.plan_name

              status.usage_reports.each do |report|
                xml.usage(:metric => report.metric_name, :period => report.period) do
                  xml.period_start  report.period_start.strftime(TIME_FORMAT)
                  xml.period_end    report.period_end.strftime(TIME_FORMAT)
                  xml.max_value     report.max_value
                  xml.current_value report.current_value
                end
              end
            end
          else
            xml.errors do
              xml.error status.rejection_reason_text, :code => status.rejection_reason_code
            end
          end

          xml.target!
        end
      end
    end
  end
end
