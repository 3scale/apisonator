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

        def initialize(contract, current_values, timestamp = Time.now.getutc)
          @contract       = contract
          @timestamp      = timestamp
          @current_values = current_values
          @authorized     = true
        end

        def reject!(code)
          @authorized = false
          @rejection_reason_code ||= code
        end
      
        attr_reader :timestamp
        attr_reader :rejection_reason_code

        def rejection_reason_text
          ERROR_MESSAGES[rejection_reason_code]
        end

        def authorized?
          @authorized
        end

        def plan_name
          @contract.plan_name
        end

        def usage_reports
          @usage_report ||= load_usage_reports
        end

        def current_value_for_usage_limit(usage_limit)
          values = @current_values[usage_limit.period]
          values && values[usage_limit.metric_id] || 0
        end

        def to_xml(options = {})
          Serializers::Status.serialize(self, options)
        end

        private

        def load_usage_reports
          @contract.usage_limits.map do |usage_limit|
            UsageReport.new(self, usage_limit)
          end
        end
      end
    end
  end
end
