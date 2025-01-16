module ThreeScale
  module Backend
    class << self
      def component
        @component ||= ENV['BACKEND_COMPONENT'] || 'worker'
      end

      def listener?
        component == 'listener'
      end

      def worker?
        component == 'worker'
      end
    end
  end
end
