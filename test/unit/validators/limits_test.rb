require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Validators
  class LimitsTest < Test::Unit::TestCase
    include TestHelpers::Sequences
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
      status = Transactor::Status.new(:service     => @service,
                                      :application => @application,
                                      :values      => {:day => {@metric_id => 7000000}})
      assert Limits.apply(status, {})
    end

    test 'succeeds if there are usage limits and none of them is exceeded' do
      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :day        => 4)

      status = Transactor::Status.new(:service     => @service,
                                      :application => @application,
                                      :values      => {:day => {@metric_id => 3}})
      assert Limits.apply(status, {})
    end

    test 'fails when current usage exceeds the limits' do
      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :day        => 4)

      status = Transactor::Status.new(:service     => @service,
                                      :application => @application,
                                      :values      => {:day => {@metric_id => 6}})
      assert !Limits.apply(status, {})

      assert_equal 'limits_exceeded',           status.rejection_reason_code
      assert_equal 'usage limits are exceeded', status.rejection_reason_text
    end

    test 'succeeds when a set does not exceed the limits' do
      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :day        => 10)

      status = Transactor::Status.new(:service     => @service,
                                      :application => @application,
                                      :values      => {:day => {@metric_id => 3}})
      assert Limits.apply(status, :usage => {'hits' => '#10'})
    end

    test 'fails when a set exceeds the limits' do
      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :day        => 10)

      status = Transactor::Status.new(:service     => @service,
                                      :application => @application,
                                      :values      => {:day => {@metric_id => 3}})
      assert !Limits.apply(status, :usage => {'hits' => '#11'})

      assert_equal 'limits_exceeded',           status.rejection_reason_code
      assert_equal 'usage limits are exceeded', status.rejection_reason_text
    end

    test 'fails when current usage + predicted usage exceeds the limits' do
      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :day        => 4)

      status = Transactor::Status.new(:service     => @service,
                                      :application => @application,
                                      :values      => {:day => {@metric_id => 3}})
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

      status = Transactor::Status.new(:service     => @service,
                                      :application => @application,
                                      :values      => {:day => {metric_one_id => 5,
                                                                metric_two_id => 2}})

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

      status = Transactor::Status.new(:service     => @service,
                                      :application => @application,
                                      :values      => {:day => {metric_one_id => 5,
                                                                metric_two_id => 2}})

      assert !Limits.apply(status, :usage => {'hits' => 1})
    end

    test 'fails if limits for the metrics in the predicted usage are exceeded even if the predicted usage is zero' do
      UsageLimit.save(:service_id => @service.id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :day        => 4)

      status = Transactor::Status.new(:service     => @service,
                                      :application => @application,
                                      :values      => {:day => {@metric_id => 6}})

      assert !Limits.apply(status, :usage => {'hits' => 0})
    end

    test 'lowest limit exceeded is nil when there are no limits defined' do
      status = Transactor::Status.new(:service => @service,
                                      :application => @application,
                                      :values => { :day => { @metric_id => 1 } })

      limits_validator = Limits.new(status, { :usage => { 'hits' => 1 } })

      assert_nil limits_validator.lowest_limit_exceeded
    end

    test 'lowest limit exceeded is nil when there are no limits exceeded' do
      limit_day = 10

      UsageLimit.save(:service_id => @service.id,
                      :plan_id => @plan_id,
                      :metric_id => @metric_id,
                      :day => limit_day)

      status = Transactor::Status.new(:service => @service,
                                      :application => @application,
                                      :values => { :day => { @metric_id => 0 } })

      limits_validator = Limits.new(status, { :usage => { 'hits' => limit_day - 1 } })

      assert_nil limits_validator.lowest_limit_exceeded
    end

    test 'calculates correct lowest limit exceeded when there are only application limits' do
      limit_day = 10
      limit_month = 100
      limit_year = 1000

      UsageLimit.save(:service_id => @service.id,
                      :plan_id => @plan_id,
                      :metric_id => @metric_id,
                      :day => limit_day,
                      :month => limit_month,
                      :year => limit_year)

      status = Transactor::Status.new(
          :service => @service,
          :application => @application,
          :values => { :day => { @metric_id => 0 },
                       :month => { @metric_id => 0 },
                       :year => { @metric_id => 0 } })

      limits_validator = Limits.new(status, { :usage => { 'hits' => limit_month + 1 } })

      assert_equal({ :usage => limit_month + 1, :max_allowed => limit_day },
                   limits_validator.lowest_limit_exceeded)

    end

    test 'calculates correct lowest limit exceeded when there are several metrics limited' do
      # We create 2 usage limits on 2 different metrics. One of the metrics has
      # both a higher limit and the report is going to exceed that limit by a
      # higher %. We want to check that the metric in the result is the one
      # that has a lower limit, not the one that was exceeded by a larger % of
      # use.

      metric1 = Metric.save(:service_id => @service.id, :id => next_id, :name => 'm1')
      metric2 = Metric.save(:service_id => @service.id, :id => next_id, :name => 'm2')

      metric1_day_limit = 10
      metric2_day_limit = 1

      metric1_report = metric1_day_limit*10
      metric2_report = metric2_day_limit*2

      UsageLimit.save(:service_id => @service.id,
                      :plan_id => @plan_id,
                      :metric_id => metric1.id,
                      :day => metric1_day_limit)

      UsageLimit.save(:service_id => @service.id,
                      :plan_id => @plan_id,
                      :metric_id => metric2.id,
                      :day => metric2_day_limit)

      status = Transactor::Status.new(:service => @service,
                                      :application => @application,
                                      :values => { :day => { metric1.id.to_sym => 0,
                                                             metric2.id.to_sym => 0} })

      limits_validator = Limits.new(status,
                                    { :usage => { metric1.name => metric1_report,
                                                  metric2.name => metric2_report } })

      assert_equal({ :usage => metric2_report, :max_allowed => metric2_day_limit },
                   limits_validator.lowest_limit_exceeded)
    end

    test 'calculates correct lowest limit exceeded when there are only user limits' do
      user_plan_id = next_id
      limit_day = 10
      limit_month = 100
      limit_year = 1000

      user = User.save!(:service_id => @service.id,
                        :username => 'a_username',
                        :state => :active,
                        :plan_id => user_plan_id,
                        :plan_name => 'a_plan_name')

      UsageLimit.save(:service_id => @service.id,
                      :plan_id => user_plan_id,
                      :metric_id => @metric_id,
                      :day => limit_day,
                      :month => limit_month,
                      :year => limit_year)

      status = Transactor::Status.new(:service => @service,
                                      :application => @application,
                                      :user => user,
                                      :user_values => { :day => { @metric_id => 0 },
                                                        :month => { @metric_id => 0 },
                                                        :year => { @metric_id => 0 } })

      limits_validator = Limits.new(status, { :usage => { 'hits' => limit_month + 1 } })

      assert_equal({ :usage => limit_month + 1, :max_allowed => limit_day },
                   limits_validator.lowest_limit_exceeded)
    end

    test 'calculates correct lowest limit exceeded when there are application and user limits' do
      app_limit_day = 10 # Lower limit, so the one that should be in the result
      user_limit_day = 20
      report_day = 30
      user_plan_id = next_id

      UsageLimit.save(:service_id => @service.id,
                      :plan_id => @plan_id,
                      :metric_id => @metric_id,
                      :day => app_limit_day)

      User.save!(:service_id => @service.id,
                 :username => 'a_username',
                 :state => :active,
                 :plan_id => user_plan_id,
                 :plan_name => 'a_plan_name')

      UsageLimit.save(:service_id => @service.id,
                      :plan_id => user_limit_day,
                      :metric_id => @metric_id,
                      :day => user_limit_day)

      status = Transactor::Status.new(:service => @service,
                                      :application => @application,
                                      :values => { :day => { @metric_id => 0 } })

      limits_validator = Limits.new(status, { :usage => { 'hits' => report_day } })

      assert_equal({ :usage => report_day, :max_allowed => app_limit_day },
                   limits_validator.lowest_limit_exceeded)
    end
  end
end
