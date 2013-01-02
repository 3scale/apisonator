module ThreeScale
  module Backend
    class Memoizer
      
      EXPIRE = 60
      PURGE = 60
      MAX_ENTRIES = 10000
      ACTIVE = true
        
      def self.reset!
        $_memoizer_cache = Hash.new
        $_memoizer_cache_expires = Hash.new
        $_memoizer_purge_time = nil
      end
      
      def self.memoized?(key)
        return false unless ACTIVE
        $_memoizer_cache ||= Hash.new
        $_memoizer_cache_expires ||= Hash.new
        now = Time.now.getutc.to_i
        
        is_memoized = ($_memoizer_cache.has_key?(key) && $_memoizer_cache_expires.has_key?(key) && (now - $_memoizer_cache_expires[key]) < EXPIRE)
        purge(now) if ($_memoizer_purge_time.nil? || (now - $_memoizer_purge_time) > PURGE)
        
        $_memoizer_stats_count = ($_memoizer_stats_count || 0) + 1  
        $_memoizer_stats_hits = ($_memoizer_stats_hits || 0) + 1 if is_memoized
        
        return is_memoized
      end
      
      def self.memoize(key, obj)
        return obj unless ACTIVE
        $_memoizer_cache ||= Hash.new
        $_memoizer_cache_expires ||= Hash.new
        $_memoizer_cache[key] = obj
        $_memoizer_cache_expires[key] = Time.now.getutc.to_i
        obj
      end
      
      def self.get(key)
        $_memoizer_cache[key]
      end
      
      def self.purge(time)
        ## not thread safe
        $_memoizer_purge_time = time
        
        $_memoizer_cache_expires.each do |key, inserted_at| 
          if (time - inserted_at > EXPIRE)
            $_memoizer_cache_expires.delete(key)
            $_memoizer_cache.delete(key)
          end
        end
        
        ##safety, should never reach this unless massive concurrency
        reset! if $_memoizer_cache_expires.size > MAX_ENTRIES
        
      end
      
      def self.stats
        $_memoizer_cache ||= Hash.new
        $_memoizer_cache_expires ||= Hash.new
        {:size => $_memoizer_cache.size, :count => ($_memoizer_stats_count || 0), :hits => ($_memoizer_stats_hits || 0)}
      end
      
      def self.memoize_block(key, &block)
        if !memoized?(key)
          Memoizer.memoize(key, yield)
        else
          Memoizer.get(key)
        end
      end
      
    end
  end
end
    