module ThreeScale
  module Backend
    module Transactor
      class Status
        def initialize(contract)
          @contract = contract
        end

        delegate :plan_name, :to => :contract

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
      end
    end
  end
end
