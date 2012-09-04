module TestHelpers
  module Fixtures
    include ThreeScale
    include ThreeScale::Backend

    def self.included(base)
      base.send(:include, TestHelpers::Sequences)
    end

    private

    def setup_master_fixtures
      @master_service_id = ThreeScale::Backend.configuration.master_service_id.to_s

      @master_hits_id         = next_id
      @master_reports_id      = next_id
      @master_authorizes_id   = next_id
      @master_transactions_id = next_id
      @master_provider_key    = "master_provider_key_#{next_id}"

      Metric.save(
        :service_id => @master_service_id, :id => @master_hits_id, :name => 'hits',
        :children => [
          Metric.new(:id => @master_reports_id,    :name => 'transactions/create_multiple'),
          Metric.new(:id => @master_authorizes_id, :name => 'transactions/authorize')])

      Metric.save(
        :service_id => @master_service_id, :id => @master_transactions_id,
        :name => 'transactions')
        
      Service.save!(:provider_key => @master_provider_key, :id => @master_service_id)  

      @master_plan_id = next_id
    end

    def setup_provider_fixtures
      setup_master_fixtures unless @master_service_id

      @provider_application_id = next_id
      @provider_key = "provider_key#{@provider_application_id}"

      Application.save(:service_id => @master_service_id,
                       :id         => @provider_application_id,
                       :state      => :active,
                       :plan_id    => @master_plan_id)

      Application.save_id_by_key(@master_service_id,
                                 @provider_key,
                                 @provider_application_id)

      @service_id = next_id
      @service = Core::Service.save!(:provider_key => @provider_key, :id => @service_id)

      @plan_id = next_id
      @plan_name = "plan#{@plan_id}"
    end

    def setup_provider_fixtures_multiple_services
      setup_master_fixtures unless @master_service_id

      @provider_application_id = next_id
      @provider_key = "provider_key#{@provider_application_id}"

      Application.save(:service_id => @master_service_id,
                       :id         => @provider_application_id,
                       :state      => :active,
                       :plan_id    => @master_plan_id)

      Application.save_id_by_key(@master_service_id,
                                 @provider_key,
                                 @provider_application_id)

      service_id = next_id
      @service_1 = Core::Service.save!(:provider_key => @provider_key, :id => service_id)

      service_id = next_id
      @service_2 = Core::Service.save!(:provider_key => @provider_key, :id => service_id)

      service_id = next_id
      @service_3 = Core::Service.save!(:provider_key => @provider_key, :id => service_id)

      @plan_id_1 = next_id
      @plan_name_1 = "plan#{@plan_id_1}"

      @plan_id_2 = next_id
      @plan_name_2 = "plan#{@plan_id_2}"

      @plan_id_3 = next_id
      @plan_name_3 = "plan#{@plan_id_3}"

    end



    def setup_oauth_provider_fixtures
      setup_provider_fixtures
      @service = Core::Service.save!(:provider_key => @provider_key, :id => @service_id, :backend_version => 'oauth')
    end
  end
end
