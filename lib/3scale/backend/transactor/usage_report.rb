module ThreeScale
  module Backend
    module Transactor
      class Status
        class UsageReport
          attr_reader :type, :period

          def initialize(status, usage_limit)
            @status      = status
            @usage_limit = usage_limit
            @period      = usage_limit.period.new(status.timestamp)
          end

          def metric_name
            @metric_name ||= @status.application.metric_name(metric_id)
          end

          def metric_id
            @usage_limit.metric_id
          end

          def max_value
            @usage_limit.value
          end

          def current_value
            @current_value ||= @status.value_for_usage_limit(@usage_limit)
          end

          # Returns -1 if the period is eternity. Otherwise, returns the time
          # remaining until the end of the period in seconds.
          def remaining_time(from = Time.now)
            if period.granularity == Period::Granularity::Eternity
              -1
            else
              (period.finish - from).ceil
            end
          end

          # Returns the number of identical calls that can be made before
          # violating the limits defined in the usage report.
          #
          # Authrep (with actual usage): suppose that we have a metric with a
          # daily limit of 10, a current usage of 0, and a given usage of 2.
          # After taking into account the given usage, the number of identical
          # calls that could be performed is (10-2)/2 = 4.
          #
          # Authorize (with predicted usage): suppose that we have a metric
          # with a daily limit of 10, a current usage of 0, and a given usage
          # of 2. This time, the given usage is not taken into account, as it
          # is predicted, not to be reported. The number of identical calls
          # that could be performed is 10/2 = 5.
          #
          # Returns -1 when there is not a limit in the number of calls.
          def remaining_same_calls
            return 0 if remaining <= 0

            usage = compute_usage
            usage > 0 ? remaining/usage : -1
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

          def to_xml
            xml = String.new
            # Node header
            add_head(xml)
            # Node content
            add_period(xml) if period != Period[:eternity]
            add_values(xml)
            # Node closing
            add_tail(xml)
            xml
          end

          private

          def hierarchy
            @status.hierarchy
          end

          def add_head(xml)
            xml << '<usage_report metric="'.freeze
            xml << metric_name.to_s << '" period="'.freeze
            xml << period.to_s << '"'.freeze
            xml << (exceeded? ? ' exceeded="true">'.freeze : '>'.freeze)
          end

          def add_period(xml)
            xml << '<period_start>'.freeze
            xml << period.start.strftime(TIME_FORMAT) << '</period_start>'.freeze
            xml << '<period_end>'.freeze
            xml << period.finish.strftime(TIME_FORMAT) << '</period_end>'.freeze
          end

          def add_values(xml)
            xml << '<max_value>'.freeze
            xml << max_value.to_s << '</max_value><current_value>'.freeze
            xml << compute_current_value.to_s
            xml << '</current_value>'
          end

          def add_tail(xml)
            xml << '</usage_report>'.freeze
          end

          def remaining
            # The remaining could be negative for several reasons:
            # 1) We allow reports that do not check limits.
            # 2) The reports included in authreps are async.
            # 3) A usage passed by param in an authrep can go over the limits.
            # However, a negative remaining does not make much sense. It's
            # better to return just 0.
            [max_value - compute_current_value, 0].max
          end

          def compute_usage
            usage = @status.usage || @status.predicted_usage

            return 0 unless usage

            this_usage = usage[metric_name] || 0
            res = Usage.get_from(this_usage)

            add_descendants_usage(usage, res)
          end

          # helper to compute the current usage value after applying a possibly
          # non-existent usage (or possibly unauthorized state)
          def compute_current_value
            # If not authorized or nothing to add, we just report the current
            # value from the data store.
            if authorized? && usage
              this_usage = usage[metric_name] || 0
              # this is an auth/authrep request and therefore we should sum the usage
              computed_usage = Usage.get_from this_usage, current_value
              # children can alter the resulting current value
              add_descendants_usage(usage, computed_usage)
            else
              current_value
            end
          end

          def add_descendants_usage(usages, parent_usage)
            descendants = Metric.descendants(@status.service_id, metric_name)

            descendants.reduce(parent_usage) do |acc, descendant|
              descendant_usage = usages[descendant]
              Usage.get_from descendant_usage, acc
            end
          end
        end
      end
    end
  end
end
