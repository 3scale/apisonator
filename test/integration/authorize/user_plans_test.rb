require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class UserPlansTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::StorageKeys
  include TestHelpers::Errors

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!
    Memoizer.reset!

    setup_provider_fixtures_multiple_services

    @application_1 = Application.save(:service_id => @service_1.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id_1,
                                    :plan_name  => @plan_name_1)

    @application_2 = Application.save(:service_id => @service_2.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id_2,
                                    :plan_name  => @plan_name_2)

    @application_3 = Application.save(:service_id => @service_3.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id_3,
                                    :plan_name  => @plan_name_3)

    @metric_id_1 = next_id
    Metric.save(:service_id => @service_1.id, :id => @metric_id_1, :name => 'hits')

    @metric_id_2 = next_id
    Metric.save(:service_id => @service_2.id, :id => @metric_id_2, :name => 'hits')

    @metric_id_3 = next_id
    Metric.save(:service_id => @service_3.id, :id => @metric_id_3, :name => 'hits')

    UsageLimit.save(:service_id => @service_1.id,
                    :plan_id    => @plan_id_1,
                    :metric_id  => @metric_id_1,
                    :day => 100)

    UsageLimit.save(:service_id => @service_2.id,
                    :plan_id    => @plan_id_2,
                    :metric_id  => @metric_id_2,
                    :day => 100)

    UsageLimit.save(:service_id => @service_3.id,
                    :plan_id    => @plan_id_3,
                    :metric_id  => @metric_id_3,
                    :day => 100)
  end
end
