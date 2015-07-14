require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class AlertsTest < Test::Unit::TestCase
  def setup
    @service_id = 10

    Alerts::ALERT_BINS.each { |val| AlertLimit.save(@service_id, val) }
  end

  test 'check proper use of bins' do
    assert_equal Alerts.utilization_discrete(0.0), 0
    assert_equal Alerts.utilization_discrete(0.5), 50
    assert_equal Alerts.utilization_discrete(0.89), 80
    assert_equal Alerts.utilization_discrete(1.22), 120
    assert_equal Alerts.utilization_discrete(6.02), 300
  end
end
