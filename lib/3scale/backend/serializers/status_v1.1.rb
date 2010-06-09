module ThreeScale
  module Backend
    module Serializers
      module StatusV1_1
        def self.serialize(status, options = {})
          xml = Builder::XmlMarkup.new
          xml.instruct! unless options[:skip_instruct]

          xml.status do
            xml.authorized status.authorized? ? 'true' : 'false'
            xml.reason     status.rejection_reason_text unless status.authorized?

            xml.plan       status.plan_name

            unless status.usage_reports.empty?
              xml.usage_reports do
                status.usage_reports.each do |report|
                  attributes = {:metric => report.metric_name,
                                :period => report.period}
                  attributes[:exceeded] = 'true' if report.exceeded?

                  xml.usage_report(attributes) do
                    xml.period_start  report.period_start.strftime(TIME_FORMAT)
                    xml.period_end    report.period_end.strftime(TIME_FORMAT)
                    xml.max_value     report.max_value
                    xml.current_value report.current_value
                  end
                end
              end
            end
          end

          xml.target!
        end
      end
    end
  end
end
