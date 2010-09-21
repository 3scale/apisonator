require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Validators
  class LimitsTest < Test::Unit::TestCase
    include TestHelpers::Sequences
    include Validators

    def setup
      Storage.instance(true).flushdb
      Resque.reset!

      @service_id     = next_id
      @plan_id        = next_id
      @metric_id      = next_id

      Metric.save(:service_id => @service_id, :id => @metric_id, :name => 'hits')

      @application = Application.save(:service_id => @service_id,
                                      :id         => next_id,
                                      :state      => :active,
                                      :plan_id    => @plan_id)
    end

    test 'succeeds if there are no usage limits' do
      status = Transactor::Status.new(nil, @application, :day => {@metric_id => 7000000})
      assert Limits.apply(status, {})
    end
    
    test 'succeeds if there are usage limits that are not exceeded' do
      UsageLimit.save(:service_id => @service_id, 
                      :plan_id    => @plan_id, 
                      :metric_id  => @metric_id,
                      :day        => 4)

      status = Transactor::Status.new(nil, @application, :day => {@metric_id => 3})
      assert Limits.apply(status, {})
    end

    test 'fails when usage limits are exceeded' do
      UsageLimit.save(:service_id => @service_id, 
                      :plan_id    => @plan_id, 
                      :metric_id  => @metric_id,
                      :day        => 4)

      status = Transactor::Status.new(nil, @application, :day => {@metric_id => 6})
      assert !Limits.apply(status, {})

      assert_equal 'limits_exceeded',           status.rejection_reason_code
      assert_equal 'usage limits are exceeded', status.rejection_reason_text
    end
  end
end
