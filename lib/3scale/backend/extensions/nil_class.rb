module ThreeScale
  module Backend
    module Extensions
      module NilClass
        def blank?
          true
        end
      end
    end
  end
end

NilClass.send(:include, ThreeScale::Backend::Extensions::NilClass)
