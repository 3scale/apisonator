module ThreeScale
  module Backend
    class Statsd
      include Configurable

      class << self
        def instance
          @instance ||= ::Statsd.new(configuration.statsd.host,
                                     configuration.statsd.port)
        end
      end
    end
  end
end
