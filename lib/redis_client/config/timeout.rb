# frozen_string_literal: true

class RedisClient
  class Config
    module Timeout
      def retry_connecting?(attempt, error)
        # Timeouts are the only "ConnectionError" that are not safe to
        # retry.
        # This conditional raise solves this issue
        # https://github.com/redis/redis-rb/issues/668. In the example shown,
        # there's a timeout while deleting a bit set, and the command is
        # executed twice in Redis.
        return false if error.is_a?(TimeoutError)
        super attempt, error
      end
    end
  end
end

RedisClient::Config::Common.prepend(RedisClient::Config::Timeout)
