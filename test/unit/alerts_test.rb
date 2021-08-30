require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require '3scale/backend/alert_limit'

class AlertsTest < Test::Unit::TestCase
  include TestHelpers::Sequences

  def setup
    @storage = Storage.instance(true)
    @service_id = next_id
    @application_id = next_id
  end

  test 'check proper use of bins' do
    assert_equal Alerts.utilization_discrete(0.0), 0
    assert_equal Alerts.utilization_discrete(0.5), 50
    assert_equal Alerts.utilization_discrete(0.89), 80
    assert_equal Alerts.utilization_discrete(1.22), 120
    assert_equal Alerts.utilization_discrete(6.02), 300
  end

  test 'can_raise_more_alerts? returns false when there are no allowed bins' do
    assert_false(Alerts.can_raise_more_alerts?(@service_id, @application_id))
  end

  test 'can_raise_more_alerts? returns false when there is already an alert for the highest bin' do
    allowed_bins = [50, 100]
    allowed_bins.each { |bin| AlertLimit.save(@service_id, bin) }

    key_highest_already_notified = Alerts.send(
      :key_already_notified, @service_id, @application_id, allowed_bins.sort.last
    )
    @storage.set(key_highest_already_notified, '1')

    assert_false(Alerts.can_raise_more_alerts?(@service_id, @application_id))
  end

  test 'can_raise_more_alerts? returns true when there are no alerts for the highest bin' do
    allowed_bins = [50, 100, 200]
    allowed_bins.each { |bin| AlertLimit.save(@service_id, bin) }

    # Set notified for a level that's not the highest
    key_already_notified = Alerts.send(
      :key_already_notified, @service_id, @application_id, allowed_bins.sort[-2]
    )
    @storage.set(key_already_notified, '1')

    assert_true(Alerts.can_raise_more_alerts?(@service_id, @application_id))
  end
end
