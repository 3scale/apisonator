module ThreeScale
  module Backend
    module Transactor
      class Status
        class UsageReport
          attr_reader :type

          def initialize(status, usage_limit, type)
            @status      = status
            @usage_limit = usage_limit
            @type        = type
          end

          def metric_name
            @metric_name ||=
              if @type == :application
                @status.application.metric_name(@usage_limit.metric_id)
              else
                @status.user.metric_name(@usage_limit.metric_id)
              end
          end

          def period
            @usage_limit.period
          end

          def period_start
            @status.timestamp.beginning_of_cycle(period)
          end

          def period_end
            @status.timestamp.end_of_cycle(period)
          end

          def max_value
            @usage_limit.value
          end

          def current_value
            @status.value_for_usage_limit(@usage_limit, @type)
          end

          def usage
            @status.usage
          end

          def exceeded?
            current_value > max_value
          end

          def authorized?
            @status.authorized?
          end

          def inspect
            "#<#{self.class.name} " \
              "type=#{type} " \
              "period=#{period} " \
              "metric_name=#{metric_name} " \
              "max_value=#{max_value} " \
              "current_value=#{current_value}>"
          end

          def to_h
            { period: period,
              metric_name: metric_name,
              max_value: max_value,
              current_value: current_value }
          end
        end

      end
    end
  end
end
