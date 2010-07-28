module ThreeScale
  module Backend
    module Transactor
      # Job for notifying about backend calls. 
      class NotifyJob
        extend Configurable

        @queue = :main

        def self.perform(provider_key, usage, timestamp)
          if contract = Contract.load(master_service_id, provider_key)
            master_metrics = Metric.load_all(master_service_id)

            ProcessJob.perform([{:service_id  => master_service_id,
                                 :contract_id => contract.id,
                                 :timestamp   => timestamp,
                                 :usage       => master_metrics.process_usage(usage)}])
          end
        end

        def self.master_service_id
          value = configuration.master_service_id
          value ? value.to_s : raise("Can't find master service id. Make sure the \"master_service_id\" configuration value is set correctly")
        end
      end
    end
  end
end
