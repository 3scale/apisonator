require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Validators
  class LimitsTest < Test::Unit::TestCase
    include TestHelpers::Sequences
    include TestHelpers::Fixtures
    include Validators

    def setup
      Storage.instance(true).flushdb
      Resque.reset!

      @service = Service.save!(:provider_key => 'foo', :id => next_id)
      @plan_id = next_id

      @metric_id = next_id
      Metric.save(:service_id => @service.id, :id => @metric_id, :name => 'hits')

      @application = Application.save(:service_id => @service.id,
                                      :id         => next_id,
                                      :state      => :active,
                                      :plan_id    => @plan_id)
    end

    test 'succeeds if there are no usage limits' do
      status = Transactor::Status.new(service_id: @service.id,
                                      application: @application,
                                      values: { day: { @metric_id => 7000000 }})
      assert Limits.apply(status, {})
    end

    test 'succeeds if there are usage limits and none of them is exceeded' do
      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :day        => 4)

      status = Transactor::Status.new(service_id: @service.id,
                                      application: @application,
                                      values: { day: { @metric_id => 3 }})
      assert Limits.apply(status, {})
    end

    test 'fails when current usage exceeds the limits' do
      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :day        => 4)

      status = Transactor::Status.new(service_id: @service.id,
                                      application: @application,
                                      values: { day: { @metric_id => 6 }})
      assert !Limits.apply(status, {})

      assert_equal 'limits_exceeded',           status.rejection_reason_code
      assert_equal 'usage limits are exceeded', status.rejection_reason_text
    end

    test 'succeeds when a set does not exceed the limits' do
      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :day        => 10)

      status = Transactor::Status.new(service_id: @service.id,
                                      application: @application,
                                      values: { day: { @metric_id => 3 }})
      assert Limits.apply(status, :usage => {'hits' => '#10'})
    end

    test 'fails when a set exceeds the limits' do
      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :day        => 10)

      status = Transactor::Status.new(service_id: @service.id,
                                      application: @application,
                                      values: { day: { @metric_id => 3 }})
      assert !Limits.apply(status, :usage => {'hits' => '#11'})

      assert_equal 'limits_exceeded',           status.rejection_reason_code
      assert_equal 'usage limits are exceeded', status.rejection_reason_text
    end

    test 'fails when current usage + predicted usage exceeds the limits' do
      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :day        => 4)

      status = Transactor::Status.new(service_id: @service.id,
                                      application: @application,
                                      values: { day: { @metric_id => 3 }})
      assert !Limits.apply(status, :usage => {'hits' => 2})

      assert_equal 'limits_exceeded',           status.rejection_reason_code
      assert_equal 'usage limits are exceeded', status.rejection_reason_text
    end

    test 'succeeds when only limits for the metrics not in the predicted usage are exceeded' do
      metric_one_id = @metric_id

      metric_two_id = next_id
      Metric.save(:service_id => @service.id, :id => metric_two_id, :name => 'hacks')

      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => metric_one_id,
                      :day        => 4)

      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => metric_two_id,
                      :day        => 4)

      status = Transactor::Status.new(service_id: @service.id,
                                      application: @application,
                                      values: { day: { metric_one_id => 5,
                                                       metric_two_id => 2 }})

      assert Limits.apply(status, :usage => {'hacks' => 1})
    end

    test 'fails if limits for the metrics in the predicted usage are exceeded' do
      metric_one_id = @metric_id

      metric_two_id = next_id
      Metric.save(:service_id => @service.id, :id => metric_two_id, :name => 'hacks')

      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => metric_one_id,
                      :day        => 4)

      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => metric_two_id,
                      :day        => 4)

      status = Transactor::Status.new(service_id: @service.id,
                                      application: @application,
                                      values: { day: { metric_one_id => 5,
                                                       metric_two_id => 2 }})

      assert !Limits.apply(status, :usage => {'hits' => 1})
    end

    test 'fails if limits for the metrics in the predicted usage are exceeded even if the predicted usage is zero' do
      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :day        => 4)

      status = Transactor::Status.new(service_id: @service.id,
                                      application: @application,
                                      values: { day: { @metric_id => 6 }})

      assert !Limits.apply(status, :usage => {'hits' => 0})
    end
  end
end
