module ThreeScale
  module Backend
    module Extensions
      module Hash
        def symbolize_names
          inject({}) do |memo, (key, value)|
            memo[key.to_sym] = value
            memo
          end
        end

        def valid_encoding?
          self.each do |k, v|
            return false if k.is_a?(String) && !k.valid_encoding?
            if v.is_a?(String) || v.is_a?(Array) || v.is_a?(Hash)
              return false unless v.valid_encoding?
            end
          end
          return true
        end
      end
    end
  end
end

Hash.send(:include, ThreeScale::Backend::Extensions::Hash)
