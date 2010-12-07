module ThreeScale
  module Backend
    module Extensions
      module Hash
        def symbolize_keys
          inject({}) do |memo, (key, value)|
            memo[key.to_sym] = value
            memo
          end
        end

        def slice(*keys)
          keys.inject({}) do |memo, key|
            memo[key] = self[key] if has_key?(key)
            memo
          end
        end
      end
    end
  end
end

Hash.send(:include, ThreeScale::Backend::Extensions::Hash)
