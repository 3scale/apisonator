require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class AlertsTest < Test::Unit::TestCase
  include Backend::Alerts

  def setup

    @service_id = 10

    Alerts::ALERT_BINS.each do |val|
      add_allowed_limit(@service_id, val)
    end
  end

  test 'check proper use of bins' do
     
      assert_equal utilization_discrete(0.0), 0
      assert_equal utilization_discrete(0.5), 50
      assert_equal utilization_discrete(0.89), 80
      assert_equal utilization_discrete(1.22), 120
      assert_equal utilization_discrete(6.02), 300
     
  end

  test 'check for bogus limits' do 

    copy_ALERT_BINS = ALERT_BINS.clone
    delete_allowed_limit(@service_id, "100")
    delete_allowed_limit(@service_id, "90")
    assert_equal ALERT_BINS.size-2, list_allowed_limit(@service_id).size

    delete_allowed_limit(@service_id,nil)
    delete_allowed_limit(@service_id,"a100a")
    assert_equal ALERT_BINS.size-2, list_allowed_limit(@service_id).size

    add_allowed_limit(@service_id,nil)
    add_allowed_limit(@service_id,"a100a")
    assert_equal ALERT_BINS.size-2, list_allowed_limit(@service_id).size


  end

  test 'check adding and deleting allowed limits' do
 
  
    copy_ALERT_BINS = ALERT_BINS.clone
    
    copy_ALERT_BINS.each do |val|
      add_allowed_limit(10, val)
    end

    l = list_allowed_limit(@service_id)
 
    assert_equal = copy_ALERT_BINS.sort.to_json, l.sort.to_json

    copy_ALERT_BINS.delete(100)
    copy_ALERT_BINS.delete(90)

    delete_allowed_limit(@service_id, 100)
    delete_allowed_limit(@service_id, 90)
    
    assert_equal = copy_ALERT_BINS.sort.to_json, l.sort.to_json

    copy_ALERT_BINS << 100
    add_allowed_limit(@service_id, "100")
    assert_equal = copy_ALERT_BINS.sort.to_json, l.sort.to_json

    copy_ALERT_BINS << 90
    add_allowed_limit(@service_id, 90)
    assert_equal = copy_ALERT_BINS.sort.to_json, l.sort.to_json
    
  end

end
