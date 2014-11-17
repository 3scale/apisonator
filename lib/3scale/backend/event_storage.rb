module ThreeScale
  module Backend
    module EventStorage
      include StorageHelpers
      extend self

      PING_TTL    = 60
      EVENT_TYPES = [:first_traffic, :alert]

      def store(type, object)
        raise Exception.new("Event type #{type} is invalid") unless EVENT_TYPES.member?(type)
        new_id = storage.incrby(events_id_key, 1)
        event  = { id: new_id, type: type, timestamp: Time.now.utc, object: object }
        storage.zadd(events_queue_key, event[:id], encode(event))
      end

      def list
        raw_events = storage.zrevrange(events_queue_key, 0, -1)
        raw_events.map { |raw_event| decode_event(raw_event) }.reverse
      end

      def delete_range(to_id)
        to_id = to_id.to_i
        if (to_id > 0)
          return storage.zremrangebyscore(events_queue_key, 0, to_id)
        else
          return 0
        end
      end

      def delete(id)
        id = id.to_i
        (id > 0) ? storage.zremrangebyscore(events_queue_key, id, id) : 0
      end

      def size
        storage.zcard(events_queue_key)
      end

      def ping_if_not_empty
        if pending_ping? && events_hook_configured?
          begin
            store_last_ping
            request_to_events_hook
            return true
          rescue Exception => e
            Airbrake.notify(e)
            return nil
          end
        end

        return false
      end

      private

      def events_queue_key
        "events/queue"
      end

      def events_ping_key
        "events/ping"
      end

      def events_id_key
        "events/id"
      end

      def events_hook_configured?
        events_hook = ThreeScale::Backend.configuration.events_hook
        events_hook && !events_hook.empty?
      end

      def request_to_events_hook
        params = {
          secret: ThreeScale::Backend.configuration.events_hook_shared_secret,
        }
        RestClient.post(ThreeScale::Backend.configuration.events_hook, params)
      end

      def store_last_ping
        storage.pipelined do
          storage.set(events_ping_key, 1)
          storage.expire(events_ping_key, PING_TTL)
        end
      end

      def pending_ping?
        ## the queue is not empty and more than timeout has passed
        ## since the front-end was notified

        events_set_size, ping_key_value = storage.pipelined do
          storage.zcard(events_queue_key)
          storage.get(events_ping_key)
        end

        events_set_size > 0 && ping_key_value.nil?
      end

      # TODO: Remove this method. It's used only in tests and there it's
      # possible to mock a constant.
      def redef_without_warning(const, value)
        remove_const(const)
        const_set(const, value)
      end

      def decode_event(raw_event)
        event = decode(raw_event)

        # decode only symbolizes keys and parse timestamp for first level
        if obj = event[:object]
          event[:object] = obj.symbolize_keys

          if ts = event[:object][:timestamp]
            event[:object][:timestamp] = Time.parse_to_utc(ts)
          end
        end

        event
      end
    end
  end
end
