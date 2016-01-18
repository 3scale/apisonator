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

      def is_usage_set?(usage_str)
        usage_str && usage_str[0] == '#'.freeze
      end

      def get_usage_from(usage_str, current_value = 0)
        if is_usage_set? usage_str
          usage_str[1..-1].to_i
        else
          # Note: this relies on the fact that NilClass#to_i returns 0
          # and String#to_i returns 0 on non-numeric contents.
          current_value + usage_str.to_i
        end
      end
    end
  end
end
