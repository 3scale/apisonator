module TestHelpers
  # Helpers for setting up master service objects.
  module MasterService
    def self.included(base)
      base.send(:include, TestHelpers::Sequences)
    end

    private

    def setup_master_service
      @master_service_id = next_id
      ThreeScale::Backend::Service.save(
        :provider_key => ThreeScale::Backend.configuration.master_provider_key,
        :id => @master_service_id)

      @master_hits_id = next_id
      @master_reports_id = next_id
      @master_transactions_id = next_id

      master_reports      = {:name => 'transactions/create_multiple'}
      master_hits         = {:name => 'hits', :children => {@master_reports_id => master_reports}}
      master_transactions = {:name => 'transactions'}

      ThreeScale::Backend::Metrics.save(
        :service_id => @master_service_id,
        @master_hits_id => master_hits,
        @master_transactions_id => master_transactions)
    end
  end
end
