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

      ## Finally, let's ping the frontend if any event is pending
      ## for processing
      def self.ping
        EventStorage.ping_if_not_empty
        true
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
        key = Stats::Keys.applications_key_prefix(
          Stats::Keys.service_key_prefix(service_id)
        )
        if storage.sadd(key, encode_key(application_id))
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
