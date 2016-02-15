module ThreeScale
  module Backend
    module Extensions
      module String
        def blank?
          self !~ /\S/
        end
      end
    end
  end
end

String.send(:include, ThreeScale::Backend::Extensions::String)
