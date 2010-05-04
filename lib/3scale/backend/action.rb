module ThreeScale
  module Backend
    class Action
      def self.call(env)
        new.call(env)
      end
    end
  end
end
