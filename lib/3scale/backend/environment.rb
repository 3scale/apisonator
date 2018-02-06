module ThreeScale
  module Backend
    class << self
      def environment
        @environment ||= ENV['RACK_ENV'] || 'development'
      end

      def production?
        environment == 'production'
      end

      def development?
        environment == 'development'
      end

      def test?
        environment == 'test'
      end
    end
  end
end
