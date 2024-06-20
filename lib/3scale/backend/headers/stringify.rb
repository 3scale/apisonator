module ThreeScale
  module Backend
    module Headers
      module Stringify
        def stringify_consts(*consts)
          consts.each do |k|
            val = const_get k
            val = val.respond_to?(:join) ? val.join(', ') : val.to_s
            k_s = "#{k}_S".to_sym
            const_set(k_s, val.freeze)
            private_constant k_s
          end
        end
      end
    end
  end
end
