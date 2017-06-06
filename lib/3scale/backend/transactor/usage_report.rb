module ThreeScale
  module Backend
    module Transactor
      class Status
        class UsageReport
          attr_reader :type, :period

          def initialize(status, usage_limit, type)
            @status      = status
            @usage_limit = usage_limit
            @type        = type
            @period      = usage_limit.period.new(status.timestamp)
          end

          def metric_name
            @metric_name ||=
              if @type == :application
                @status.application.metric_name(metric_id)
              else
                @status.user.metric_name(metric_id)
              end
          end

          def metric_id
            @usage_limit.metric_id
          end

          def max_value
            @usage_limit.value
          end

          def current_value
            @current_value ||= @status.value_for_usage_limit(@usage_limit, @type)
          end

          def remaining
            max_value - current_value
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
              children = hierarchy[metric_name]
              if children
                # this is a parent metric, so we need to add usage we got
                # explicited in the usage parameter
                children.each do |child|
                  child_usage = usage[child]
                  computed_usage = Usage.get_from child_usage, computed_usage
                end
              end
              computed_usage
            else
              current_value
            end
          end
        end
      end
    end
  end
end
