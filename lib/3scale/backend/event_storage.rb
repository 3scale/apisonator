require 'net/http'

module ThreeScale
  module Backend
    class EventStorage
      PING_TTL    = 60
      private_constant :PING_TTL

      EVENT_TYPES = [:first_traffic, :first_daily_traffic, :alert].freeze
      private_constant :EVENT_TYPES

      class << self
        include StorageHelpers

        def store(type, object)
          fail InvalidEventType, type unless EVENT_TYPES.member?(type)
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
          if to_id > 0
            storage.zremrangebyscore(events_queue_key, 0, to_id)
          else
            0
          end
        end

        def delete(id)
          id = id.to_i
          (id > 0) ? storage.zremrangebyscore(events_queue_key, id, id) : 0
        end

        def size(strg = storage)
          strg.zcard(events_queue_key)
        end

        def ping_if_not_empty
          if events_hook && pending_ping?
            request_to_events_hook
            true
          end
        end

        private

        def events_queue_key
          "events/queue".freeze
        end

        def events_ping_key
          "events/ping".freeze
        end

        def events_id_key
          "events/id".freeze
        end

        def request_to_events_hook
          Net::HTTP.post_form(
            events_hook_uri,
            secret: events_hook_shared_secret,
          )
        end

        def events_hook
          hook = Backend.configuration.events_hook
          if hook.nil? || hook.empty?
            false
          else
            hook
          end
        end

        def events_hook_shared_secret
          Backend.configuration.events_hook_shared_secret
        end

        def events_hook_uri
          URI(events_hook)
        end

        def pending_ping?
          ## the queue is not empty and more than timeout has passed
          ## since the front-end was notified
          events_set_size, can_ping = storage.pipelined do |pipeline|
            size(pipeline)
            pipeline.set(events_ping_key, '1'.freeze, ex: PING_TTL, nx: true)
          end

          can_ping && events_set_size > 0
        end

        def decode_event(raw_event)
          event = decode(raw_event)

          # decode only symbolizes keys and parse timestamp for first level
          obj = event[:object]
          if obj
            event[:object] = obj.symbolize_names
            ts = event[:object][:timestamp]
            event[:object][:timestamp] = Time.parse_to_utc(ts) if ts
          end

          event
        end
      end
    end
  end
end
