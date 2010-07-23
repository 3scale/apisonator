module TestHelpers
  # Helpers for setting up master service objects.
  module MasterService
    include ThreeScale
    include ThreeScale::Backend

    def self.included(base)
      base.send(:include, TestHelpers::Sequences)
    end

    private

    def setup_master_service
      @master_service_id = ThreeScale::Backend.configuration.master_service_id.to_s

      @master_hits_id         = next_id
      @master_reports_id      = next_id
      @master_authorizes_id   = next_id
      @master_transactions_id = next_id

      Metric.save(
        :service_id => @master_service_id, :id => @master_hits_id, :name => 'hits',
        :children => [
          Metric.new(:id => @master_reports_id,    :name => 'transactions/create_multiple'),
          Metric.new(:id => @master_authorizes_id, :name => 'transactions/authorize')])

      Metric.save(
        :service_id => @master_service_id, :id => @master_transactions_id,
        :name => 'transactions')
    end
  end
end
