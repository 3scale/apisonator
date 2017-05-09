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
                @status.application.metric_name(metric_id)
              else
                @status.user.metric_name(metric_id)
              end
          end

          def metric_id
            @usage_limit.metric_id
          end

          def period
            @usage_limit.period
          end

          def period_start
            Period::Boundary.start_of(period, @status.timestamp)
          end

          def period_end
            Period::Boundary.end_of(period, @status.timestamp)
          end

          def max_value
            @usage_limit.value
          end

          def current_value
            @current_value ||= @status.value_for_usage_limit(@usage_limit, @type)
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
            add_period(xml) if period != :eternity
            add_values(xml)
            # Node closing
            add_tail(xml)
            xml
          end

          private

          def add_head(xml)
            xml << '<usage_report metric="'.freeze
            xml << metric_name.to_s << '" period="'.freeze
            xml << period.to_s << '"'.freeze
            xml << (exceeded? ? ' exceeded="true">'.freeze : '>'.freeze)
          end

          def add_period(xml)
            xml << '<period_start>'.freeze
            xml << period_start.strftime(TIME_FORMAT) << '</period_start>'.freeze
            xml << '<period_end>'.freeze
            xml << period_end.strftime(TIME_FORMAT) << '</period_end>'.freeze
          end

          def add_values(xml)
            xml << '<max_value>'.freeze
            xml << max_value.to_s << '</max_value><current_value>'.freeze
            xml << if authorized? && usage && (usage_metric_name = usage[metric_name])
                     # this is an authrep request and therefore we should sum the usage
                     Usage.get_from usage_metric_name, current_value
                   else
                     current_value
                   end.to_s
            xml << '</current_value>'
          end

          def add_tail(xml)
            xml << '</usage_report>'.freeze
          end

        end
      end
    end
  end
end
