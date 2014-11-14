require '3scale/backend/storage'
require '3scale/backend/event_storage'
require '3scale/backend/aggregator/stats_keys'

module ThreeScale
  module Backend
    class ApplicationEvents

      class << self
        include Core::StorageKeyHelpers
      end

      ## Finally, let's ping the frontend if any event is pending
      ## for processing
      def self.ping
        EventStorage.ping_if_not_empty
        true
      end

      def self.generate(applications)
        applications.each do |application|
          service_id     = application[:service_id]
          application_id = application[:application_id]

          first_traffic(service_id, application_id)
        end
      end

      private

      def self.first_traffic(service_id, application_id)
        key = Aggregator::StatsKeys.applications_key_prefix(
          Aggregator::StatsKeys.service_key_prefix(service_id)
        )
        if storage.sadd(key, encode_key(application_id))
          EventStorage.store(:first_traffic,
                             { service_id:     service_id,
                               application_id: application_id,
                               timestamp:      Time.now.utc.to_s })
        end
      end

      def self.storage
        Storage.instance
      end
    end
  end
end
