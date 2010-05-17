module ThreeScale
  module Backend
    module Transactor
      class Status
        class Usage
          def initialize(status, usage_limit)
            @status      = status
            @usage_limit = usage_limit
          end
        
          def metric_name
            @usage_limit.metric_name
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
            @status.current_value_for_usage_limit(@usage_limit)
          end

          def inspect
            "#<#{self.class.name} period=#{period}" +
                                " metric_name=#{metric_name}" +
                                " max_value=#{max_value}" +
                                " current_value=#{current_value}>"
          end
        end

        def initialize(contract, current_values, timestamp = Time.now.getutc)
          @contract  = contract
          @timestamp = timestamp
          @current_values = current_values
        end
      
        attr_reader :timestamp

        def plan_name
          @contract.plan_name
        end

        def usages
          @usages ||= load_usages
        end

        def current_value_for_usage_limit(usage_limit)
          values = @current_values[usage_limit.period]
          values && values[usage_limit.metric_id] || 0
        end

        TIME_FORMAT = '%Y-%m-%d %H:%M:%S'

        def to_xml(options = {})
          xml = Builder::XmlMarkup.new
          xml.instruct! unless options[:skip_instruct]

          xml.status do
            xml.plan plan_name

            usages.each do |usage|
              xml.usage(:metric => usage.metric_name, :period => usage.period) do
                xml.period_start  usage.period_start.strftime(TIME_FORMAT)
                xml.period_end    usage.period_end.strftime(TIME_FORMAT)
                xml.max_value     usage.max_value
                xml.current_value usage.current_value
              end
            end
          end

          xml.target!
        end

        private

        def load_usages
          @contract.usage_limits.map do |usage_limit|
            Usage.new(self, usage_limit)
          end
        end
      end
    end
  end
end
