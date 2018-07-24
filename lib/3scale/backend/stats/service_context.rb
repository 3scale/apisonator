# Create a keys partition generator
module ThreeScale
  module Backend
    module Stats
      class ServiceContext
          include Serialize

          ATTRIBUTES = %i[service_id metrics applications users from to].freeze
          private_constant :ATTRIBUTES
          attr_accessor(*ATTRIBUTES)
      end
    end
  end
end
