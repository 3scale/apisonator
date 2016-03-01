module ThreeScale
  module Backend
    class Usage
      class << self
        def is_set?(usage_str)
          usage_str && usage_str[0] == '#'.freeze
        end

        def get_from(usage_str, current_value = 0)
          if is_set? usage_str
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
end
