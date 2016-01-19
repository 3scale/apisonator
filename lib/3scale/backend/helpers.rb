module ThreeScale
  module Backend
    module Helpers
      module_function

      def int_to_bool(int)
        int.to_i > 0
      end

      def bool_to_int(boolean)
        boolean ? 1 : 0
      end
    end
  end
end
