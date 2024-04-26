module TestHelpers
  module Fixtures
    include ThreeScale
    include ThreeScale::Backend

    def self.included(base)
      base.send(:include, TestHelpers::Sequences)
    end

    private

    def storage(reset = false)
      Storage.instance reset
    end

    def setup_master_fixtures
      @master_service_id = ThreeScale::Backend.configuration.master_service_id.to_s

      @master_hits_id         = next_id
      @master_authorizes_id   = next_id
      @master_transactions_id = next_id
      @master_provider_key    = "master_provider_key_#{next_id}"

      Metric.save(
        :service_id => @master_service_id, :id => @master_hits_id, :name => 'hits',
        :children => [
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
      @service = Service.save!(:provider_key => @provider_key, :id => @service_id)

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
      @service_1 = Service.save!(:provider_key => @provider_key, :id => service_id)

      service_id = next_id
      @service_2 = Service.save!(:provider_key => @provider_key, :id => service_id)

      service_id = next_id
      @service_3 = Service.save!(:provider_key => @provider_key, :id => service_id)

      @plan_id_1 = next_id
      @plan_name_1 = "plan#{@plan_id_1}"

      @plan_id_2 = next_id
      @plan_name_2 = "plan#{@plan_id_2}"

      @plan_id_3 = next_id
      @plan_name_3 = "plan#{@plan_id_3}"
    end

    def setup_oauth_provider_fixtures
      setup_provider_fixtures
      @service = Service.save!(provider_key: @provider_key, id: @service_id, backend_version: 'oauth')
    end

    # alternative fixture which won't overwrite @service
    def setup_oauth_provider_fixtures_noclobber
      setup_provider_fixtures
      @service_oauth_id = next_id
      @service_oauth = Service.save!(provider_key: @provider_key, id: @service_oauth_id, backend_version: 'oauth')
    end

    def setup_oauth_provider_fixtures_multiple_services
      setup_provider_fixtures_multiple_services
      @service_1 = Service.save!(:provider_key => @provider_key, :id => @service_1.id, backend_version: 'oauth')
      @service_2 = Service.save!(:provider_key => @provider_key, :id => @service_2.id, backend_version: 'oauth')
      @service_3 = Service.save!(:provider_key => @provider_key, :id => @service_3.id, backend_version: 'oauth')
    end

    def seed_data
      #MASTER_SERVICE_ID = 1
      ## for the master
      master_service_id = ThreeScale::Backend.configuration.master_service_id
      Metric.save(
        service_id: master_service_id,
        id:         100,
        name:       'hits',
        children:   [
          Metric.new(id: 102, name: 'transactions/authorize')
        ])

      Metric.save(
        service_id: master_service_id,
        id:         200,
        name:       'transactions'
      )

      ## for the provider
      @provider_key = "provider_key"
      metrics      = []

      2.times do |i|
        i += 1
        @service_id = 1000 + i
        @app_id = 2000 + i
        Service.save!(provider_key: @provider_key, id: @service_id)
        Application.save(service_id: @service_id, id: @app_id, state: :live)
        metrics << Metric.save(service_id: @service_id, id: 3000 + i, name: 'hits')
      end
      @metric_hits = metrics.first
    end

    def default_transaction_timestamp
      Time.utc(2010, 5, 7, 13, 23, 33)
    end

    def default_transaction_attrs
      {
        service_id:     1001,
        application_id: 2001,
        timestamp:      default_transaction_timestamp,
        usage:          { '3001' => 1 },
      }
    end

    def default_transaction attrs = {}
      Transaction.new default_transaction_attrs.merge(attrs)
    end

    def transaction_with_set_value
      default_transaction usage: { '3001' => '#665' }
    end

    def transaction_with_response_code code = 200
      default_transaction response_code: code
    end

    def default_report
      Transactor.report(
        @provider_key,
        @service_id.to_s,
        0 => { app_id: @app_id.to_s, usage: { @metric_hits.name => 1 } }
      )
    end

    def setup_provider_without_default_service
      @provider_key_without_default_service = next_id

      service1 = Service.save!(provider_key: @provider_key_without_default_service,
                              id: next_id)

      Service.save!(provider_key: @provider_key_without_default_service,
                    id: next_id)

      # Delete the default service. The provider will have just 1 non-default service.
      Service.load_by_id(service1.id).tap do |service|
        service.delete_data
        service.clear_cache
      end
    end

    # Sets a service with a metric hierarchy with the number of levels specified.
    # Generates only one metric on each level.
    #
    # Returns a hash with provider_key, service_id, app_id and metrics. metrics
    # is an ordered array where the pos 0 represents the metric in the highest
    # level of the hierarchy. Each metric has: id, name, and limit.
    def setup_service_with_metric_hierarchy(levels, set_limits: true, oauth: false)
      provider_key = next_id
      service_id = next_id
      Service.save!(provider_key: provider_key,
                    id: service_id,
                    backend_version: (oauth ? :oauth : '2'))

      app_id = next_id
      plan_id = next_id
      Application.save(service_id: service_id,
                       id: app_id,
                       state: :active,
                       plan_id: plan_id)

      # The metric at pos 0 is the highest one in the hierarchy.
      # The higher the metric in the hierarchy, the higher its limit is.
      metrics_attrs = levels.times.map do |i|
        { id: next_id, name: "metric_#{i}", limit: (levels - i)*10 }
      end

      # Instantiate the metrics and set the children.
      current = nil
      metrics_attrs.reverse_each do |metric_attrs|
        children = Array(current)
        current = Metric.new(service_id: service_id,
                             id: metric_attrs[:id],
                             name: metric_attrs[:name],
                             children: children)
      end
      current.save if current # save() stores all the children recursively

      if set_limits
        metrics_attrs.each do |metric|
          UsageLimit.save(service_id: service_id,
                          plan_id: plan_id,
                          metric_id: metric[:id],
                          day: metric[:limit])
        end
      end

      {
        provider_key: provider_key,
        service_id: service_id,
        app_id: app_id,
        plan_id: plan_id,
        metrics: metrics_attrs
      }
    end
  end
end
