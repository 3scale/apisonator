module ThreeScale
  module Backend
    module ErrorStorage
      include StorageHelpers
      extend self

      PER_PAGE = 100
      MAX_NUM_ERRORS = 1000

      def store(service_id, error, context_info = {})
        request_info = context_info[:request] || {}
        storage.lpush(queue_key(service_id),
                      encode(code:         error.code,
                             message:      error.message,
                             timestamp:    Time.now.getutc.to_s,
                             context_info: request_info))
        storage.ltrim(queue_key(service_id), 0, MAX_NUM_ERRORS - 1)
      end

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

      def pagination_to_range(page, per_page)
        range_start = (page - 1) * per_page
        range_end   = range_start + per_page - 1

        range_start..range_end
      end
    end
  end
end
