module ThreeScale
  module Backend
    class Memoizer

      EXPIRE = 60
      PURGE = 60
      MAX_ENTRIES = 10000
      ACTIVE = true

      def self.reset!
        @@memoizer_cache = Hash.new
        @@memoizer_cache_expires = Hash.new
        @@memoizer_purge_time = nil
        @@memoizer_stats_count = 0
        @@memoizer_stats_hits = 0
      end

      def self.memoized?(key)
        return false unless ACTIVE
        @@memoizer_cache ||= Hash.new
        @@memoizer_cache_expires ||= Hash.new

        now = Time.now.getutc.to_i
        @@memoizer_purge_time ||= now

        is_memoized = (@@memoizer_cache.has_key?(key) && @@memoizer_cache_expires.has_key?(key) && (now - @@memoizer_cache_expires[key]) < EXPIRE)
        purge(now) if (@@memoizer_purge_time.nil? || (now - @@memoizer_purge_time) > PURGE)

        @@memoizer_stats_count ||= 0
        @@memoizer_stats_hits ||= 0

        @@memoizer_stats_count = @@memoizer_stats_count + 1
        @@memoizer_stats_hits = @@memoizer_stats_hits + 1 if is_memoized

        return is_memoized
      end

      def self.memoize(key, obj)
        return obj unless ACTIVE
        @@memoizer_cache ||= Hash.new
        @@memoizer_cache_expires ||= Hash.new
        @@memoizer_cache[key] = obj
        @@memoizer_cache_expires[key] = Time.now.getutc.to_i
        obj
      end

      def self.get(key)
        @@memoizer_cache[key]
      end

      def self.clear(keys)
        Array(keys).each do |key|
          @@memoizer_cache_expires.delete key
          @@memoizer_cache.delete key
        end
      end

      def self.purge(time)
        ## not thread safe
        @@memoizer_purge_time = time

        @@memoizer_cache_expires.each do |key, inserted_at|
          if (time - inserted_at > EXPIRE)
            @@memoizer_cache_expires.delete(key)
            @@memoizer_cache.delete(key)
          end
        end

        ##safety, should never reach this unless massive concurrency
        reset! if @@memoizer_cache_expires.size > MAX_ENTRIES
      end

      def self.stats
        @@memoizer_cache ||= Hash.new
        @@memoizer_cache_expires ||= Hash.new
        {:size => @@memoizer_cache.size, :count => (@@memoizer_stats_count || 0), :hits => (@@memoizer_stats_hits || 0)}
      end

      def self.memoize_block(key, &block)
        if !memoized?(key)
          obj = yield
          Memoizer.memoize(key, obj)
        else
          Memoizer.get(key)
        end
      end

    end
  end
end
