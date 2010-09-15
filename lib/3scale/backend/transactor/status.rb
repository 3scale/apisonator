module ThreeScale
  module Backend
    module Transactor
      class Status
        class UsageReport
          def initialize(parent, usage_limit)
            @parent      = parent
            @usage_limit = usage_limit
          end
        
          def metric_name
            @usage_limit.metric_name
          end

          def period
            @usage_limit.period
          end

          def period_start
            @parent.timestamp.beginning_of_cycle(period)
          end

          def period_end
            @parent.timestamp.end_of_cycle(period)
          end

          def max_value
            @usage_limit.value
          end

          def current_value
            @parent.current_value_for_usage_limit(@usage_limit)
          end

          def exceeded?
            current_value > max_value
          end

          def inspect
            "#<#{self.class.name} period=#{period}" +
                                " metric_name=#{metric_name}" +
                                " max_value=#{max_value}" +
                                " current_value=#{current_value}>"
          end
        end

        def initialize(application, current_values, timestamp = Time.now.getutc)
          @application    = application or raise 'application is required'
          @timestamp      = timestamp
          @current_values = current_values
          @authorized     = true
        end

        attr_reader :application
        attr_reader :current_values

        def reject!(error)
          @authorized = false
          @rejection_reason_code ||= error.code
          @rejection_reason_text ||= error.message
        end

        attr_reader :timestamp
        attr_reader :rejection_reason_code
        attr_reader :rejection_reason_text

        def authorized?
          @authorized
        end

        def plan_name
          @application.plan_name
        end

        def usage_reports
          @usage_report ||= load_usage_reports
        end

        def current_value_for_usage_limit(usage_limit)
          values = @current_values[usage_limit.period]
          values && values[usage_limit.metric_id] || 0
        end

        def to_xml(options = {})
          xml = Builder::XmlMarkup.new
          xml.instruct! unless options[:skip_instruct]

          xml.status do
            xml.authorized authorized? ? 'true' : 'false'
            xml.reason     rejection_reason_text unless authorized?

            xml.plan       plan_name

            unless usage_reports.empty?
              xml.usage_reports do
                usage_reports.each do |report|
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

        private

        def load_usage_reports
          @application.usage_limits.map do |usage_limit|
            UsageReport.new(self, usage_limit)
          end
        end
      end
    end
  end
end
