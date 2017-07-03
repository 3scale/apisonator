module ThreeScale
  module Backend
    module Period
      # A simple last-used instance cache
      #
      # This is expected to be especially effective for us since most
      # of the time what we look for is start/finish and the exact
      # timestamp does not matter.
      #
      class Cache
        @cache = {}

        class << self
          def get(granularity, start)
            cached = @cache[granularity]
            if cached && cached.start == start
              cached
            end
          end

          def set(granularity, obj)
            @cache[granularity] = obj
          end
        end
      end
    end
  end
end
