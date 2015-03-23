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

      def get_value_of_set_if_exists(value_str)
        return nil if value_str.nil? || value_str[0] != "#"
        value_str[1..value_str.size].to_i
      end
    end
  end
end
