
require 'json'

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
            @parent.application.metric_name(@usage_limit.metric_id)
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
            @parent.value_for_usage_limit(@usage_limit)
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

        def initialize(attributes = {})
          @service     = attributes[:service]
          @application = attributes[:application] or raise ':application is required'
          @values      = attributes[:values] || {}
          @timestamp   = attributes[:timestamp] || Time.now.getutc
          @authorized  = true
        end

        attr_reader :service
        attr_reader :application
        attr_reader :values
        attr_reader :predicted_values

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

        def value_for_usage_limit(usage_limit)
          values = @values[usage_limit.period]
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

										if options[:anchors_for_caching].nil?

                    	if authorized? && !options[:usage].nil? && !options[:usage][report.metric_name].nil? # this is a authrep request and therefore we should sum the usage
                      	xml.current_value report.current_value + options[:usage][report.metric_name].to_i
                    	else
                      	xml.current_value report.current_value
                    	end
										else
											## this is a hack to avoid marshalling status for caching, this way is much faster, but nastier
											## see Transactor.clean_cached_xml(xmlstr, options = {}) for futher info
											xml.current_value "|.|#{report.metric_name},#{report.current_value},#{report.max_value}|.|"
										end
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
