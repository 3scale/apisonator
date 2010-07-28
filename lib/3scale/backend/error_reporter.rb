module ThreeScale
  module Backend
    module ErrorReporter
      extend self

      def push(service_id, error)
        storage.rpush(queue_key(service_id), encode(error))
      end

      def all(service_id)
        (storage.lrange(queue_key(service_id), 0, -1) || []).map(&method(:decode))
      end

      private

      def queue_key(service_id)
        "errors/service_id:#{service_id}"
      end

      def encode(error)
        Yajl::Encoder.encode(:code      => error.code,
                             :message   => error.message,
                             :timestamp => Time.now.getutc.to_s)
      end

      def decode(encoded_error)
        error = Yajl::Parser.parse(encoded_error).symbolize_keys
        error[:timestamp] = Time.parse_to_utc(error[:timestamp]) if error[:timestamp]
        error
      end

      def storage
        Storage.instance
      end
    end
  end
end
