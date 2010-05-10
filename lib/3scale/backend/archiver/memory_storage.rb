module ThreeScale
  module Backend
    class Archiver
      # This is a stub storage class used for testing.
      class MemoryStorage
        def initialize
          @content = {}
        end

        def store(name, content)
          @content[name] = content
        end

        def [](name)
          @content[name]
        end
      end
    end
  end
end
