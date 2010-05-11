module ThreeScale
  module Backend
    module Actions
      # This is the /check.txt for haproxy.
      class Check < Action
        def perform(request)
          [200, {}, []]
        end
      end
    end
  end
end
