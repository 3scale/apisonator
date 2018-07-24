module ThreeScale
  module Backend
    module Stats
      module Keys
        class Index
          include Serialize
          ATTRIBUTES = %i[key_type metric app user granularity ts].freeze
          private_constant :ATTRIBUTES
          attr_accessor(*ATTRIBUTES)
        end
      end
    end
  end
end
