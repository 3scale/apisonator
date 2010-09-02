module ThreeScale
  module Backend
    module ErrorStorage
      extend self

      def store(service_id, error)
        storage.lpush(queue_key(service_id), encode(error))
      end

      PER_PAGE = 100

      # Pages start at 1, same as in will_paginate.
      def list(service_id, options = {})
        page     = options[:page] || 1
        per_page = options[:per_page] || PER_PAGE
        range    = pagination_to_range(page.to_i, per_page.to_i)

        raw_items = (storage.lrange(queue_key(service_id), range.begin, range.end) || [])
        raw_items.map(&method(:decode))
      end

      def count(service_id)
        storage.llen(queue_key(service_id))
      end

      def delete_all(service_id)
        storage.del(queue_key(service_id))
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

      def pagination_to_range(page, per_page)
        range_start = (page - 1) * per_page
        range_end   = range_start + per_page - 1

        range_start..range_end
      end

      def storage
        Storage.instance
      end
    end
  end
end
