module ThreeScale
  module Backend
    module Extensions
      module Array
        def valid_encoding?
          self.each do |v|
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

Array.send(:include, ThreeScale::Backend::Extensions::Array)

