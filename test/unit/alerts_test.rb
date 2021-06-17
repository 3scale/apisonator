require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require '3scale/backend/alert_limit'

class AlertsTest < Test::Unit::TestCase
  include TestHelpers::Sequences

  def setup
    @storage = Storage.instance(true)
    @service_id = next_id
    @application_id = next_id
    Application.save(
      service_id: @service_id, id: @application_id, state: :active, plan_id: @plan_id
    )
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

  # Tests for Alerts::UsagesChecked start here

  test 'when marking as checked, it also sets the key with the minimal TTL among the notified bins' do
    min_ttl = 60

    key_bin_50 = Alerts.send(:key_already_notified, @service_id, @application_id, 50)
    @storage.setex(key_bin_50, min_ttl*2, '1')

    key_bin_80 = Alerts.send(:key_already_notified, @service_id, @application_id, 80)
    @storage.setex(key_bin_80, min_ttl, '1')

    Alerts::UsagesChecked.mark_all_checked(@service_id, @application_id)

    assert_false Alerts::UsagesChecked.need_to_check_all?(@service_id, @application_id)

    # The 80% bin has a lower TTL. We cannot guarantee the exact TTL because
    # some time might pass between the moment we create the key and check its
    # TTL, but we know it needs to be <= min_ttl and close to it.
    key_checked = Alerts.send(:key_usage_already_checked, @service_id, @application_id)
    assert_true (min_ttl-10..min_ttl).include?(@storage.ttl(key_checked))
  end

  test 'when marking as checked, sets the key with TTL = 1 day if none of the bins are set as notified' do
    Alerts::UsagesChecked.mark_all_checked(@service_id, @application_id)

    assert_false Alerts::UsagesChecked.need_to_check_all?(@service_id, @application_id)

    # We can't guarantee that the TTL will be exactly one day because some
    # seconds might pass between the moment we create the key and check the TTL,
    # but it should be pretty close.
    key_checked = Alerts.send(:key_usage_already_checked, @service_id, @application_id)
    assert_true (Alerts::ALERT_TTL-10..Alerts::ALERT_TTL).include?(@storage.ttl(key_checked))
  end

  test 'when marking as checked, does not set the key if there is a bin with TTL=0' do
    Storage.instance.stubs(:ttl).returns(0)

    Alerts::UsagesChecked.mark_all_checked(@service_id, @application_id)

    assert_true Alerts::UsagesChecked.need_to_check_all?(@service_id, @application_id)
  end

  test 'can invalidate for a single app' do
    other_app_id = next_id
    Application.save(service_id: @service_id, id: other_app_id, state: :active, plan_id: @plan_id)

    [@application_id, other_app_id].each do |app_id|
      Alerts::UsagesChecked.mark_all_checked(@service_id, app_id)
    end

    Alerts::UsagesChecked.invalidate(@service_id, @application_id)
    Memoizer.reset!

    assert_true Alerts::UsagesChecked.need_to_check_all?(@service_id, @application_id)
    assert_false Alerts::UsagesChecked.need_to_check_all?(@service_id, other_app_id)
  end

  test 'can invalidate for the whole service' do
    other_app_id = next_id
    Application.save(service_id: @service_id, id: other_app_id, state: :active, plan_id: @plan_id)

    [@application_id, other_app_id].each do |app_id|
      Alerts::UsagesChecked.mark_all_checked(@service_id, app_id)
    end

    Alerts::UsagesChecked.invalidate_for_service(@service_id)
    Memoizer.reset!

    assert_true [@application_id, other_app_id].all? do |app_id|
      Alerts::UsagesChecked.need_to_check_all?(@service_id, app_id)
    end
  end
end
