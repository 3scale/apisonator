module ThreeScale
  module Backend
    module Transactor
      class Status
        class Usage
          def initialize(usage_limit, current_value)
            @usage_limit   = usage_limit
            @current_value = current_value
          end
        
          attr_reader :current_value

          def period
            @usage_limit.period
          end

          def period_start
            Time.now.getutc.beginning_of_cycle(period)
          end

          def period_end
            Time.now.getutc.end_of_cycle(period)
          end

          def max_value
            @usage_limit.value
          end
        end

        def initialize(contract)
          @contract = contract
        end

        delegate :plan_name, :to => :contract

        def usages
          @usages ||= load_usages
        end

        def to_xml(options = {})
          xml = Builder::XmlMarkup.new
          xml.instruct! unless options[:skip_instruct]

          xml.status do
            xml.plan plan_name
          end

          xml.target!
        end

        private

        attr_reader :contract

        def load_usages
          contract.usage_limits.map do |usage_limit|
            Usage.new(usage_limit, 0)
          end
        end
      end
    end
  end
end
