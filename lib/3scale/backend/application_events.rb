require '3scale/backend/storage'
require '3scale/backend/event_storage'
require '3scale/backend/stats/keys'

module ThreeScale
  module Backend
    class ApplicationEvents

      class << self
        include Backend::StorageKeyHelpers
      end

      DAILY_KEY_TTL = 172_800

      Error = Class.new StandardError
      class PingFailed < Error
        def initialize(e)
          super "Application event ping failed: #{e.class} - #{e.message}"
        end
      end

      # ping the frontend if any event is pending for processing
      def self.ping
        EventStorage.ping_if_not_empty
      rescue => e
        raise PingFailed.new(e)
      end

      def self.generate(applications)
        return if applications.nil? || applications.empty?
        applications.each do |application|
          service_id     = application[:service_id]
          application_id = application[:application_id]

          first_traffic(service_id, application_id)
          first_daily_traffic(service_id, application_id)
        end
      end

      private

      def self.first_traffic(service_id, application_id)
        if storage.sadd?(Stats::Keys.set_of_apps_with_traffic(service_id),
                         encode_key(application_id))
          EventStorage.store(:first_traffic,
                             { service_id:     service_id,
                               application_id: application_id,
                               timestamp:      Time.now.utc.to_s })
        end
      end

      def self.first_daily_traffic(service_id, application_id)
        timestamp = Time.now.utc
        day_key   = Period::Boundary.day_start(timestamp).to_compact_s
        daily_key = "daily_traffic/service:#{service_id}/" \
                    "cinstance:#{application_id}/#{day_key}"

        Memoizer.memoize_block(daily_key) do
          if storage.incr(daily_key) == 1
            storage.expire(daily_key, DAILY_KEY_TTL)
            EventStorage.store(:first_daily_traffic,
                               { service_id:     service_id,
                                 application_id: application_id,
                                 timestamp:      timestamp.to_s })
          end
        end
      end

      def self.storage
        Storage.instance
      end
    end
  end
end
