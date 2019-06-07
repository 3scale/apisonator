# Monkey-patches a method in Redis::Client::Connector::Sentinel to fix a bug
# with sentinel passwords. It applies the fix in
# https://github.com/redis/redis-rb/pull/856.
#
# The fix was included in 4.1.2, but we cannot upgrade because that version
# drops support for ruby < 2.3.0 which we still need to support.
#
# This should only be temporary. It should be deleted when updating the gem.
class Redis
  class Client
    class Connector
      class Sentinel
        def sentinel_detect
          @sentinels.each do |sentinel|
            client = Redis::Client.new(@options.merge({:host => sentinel[:host],
                                                       :port => sentinel[:port],
                                                       password: sentinel[:password],
                                                       :reconnect_attempts => 0,
                                                      }))

            begin
              if result = yield(client)
                # This sentinel responded. Make sure we ask it first next time.
                @sentinels.delete(sentinel)
                @sentinels.unshift(sentinel)

                return result
              end
            rescue BaseConnectionError
            ensure
              client.disconnect
            end
          end

          raise CannotConnectError, "No sentinels available."
        end
      end
    end
  end
end
