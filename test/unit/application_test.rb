require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class ApplicationTest < Test::Unit::TestCase
  def setup
    @storage = Storage.instance(true)
    @storage.flushdb
  end

  test 'load! raises an exception if application does not exist' do
    assert_raise ApplicationNotFound do
      Application.load!('1001', '2001')
    end
  end

  test 'load! returns application if it exists' do
    Application.save(:service_id => '1001', 
                     :id         => '2001', 
                     :state      => :active,
                     :plan_id    => '3001',
                     :plan_name  => 'cool')

    application = Application.load!('1001', '2001')

    assert_instance_of Application, application
    assert_equal '1001',  application.service_id
    assert_equal '2001',  application.id
    assert_equal :active, application.state
    assert_equal '3001',  application.plan_id
    assert_equal 'cool',  application.plan_name
  end

  test '#active? returns true if application is in active state' do
    application = Application.new(:state => :active)
    assert application.active?
  end

  test '#active? returns false if application is in suspended state' do
    application = Application.new(:state => :suspended)
    assert !application.active?
  end

  test 'application has no keys when created' do
    application = Application.save(:service_id => '1001', 
                                   :id         => '2001', 
                                   :state      => :active)

    assert application.keys.empty?
  end

  test '#create_key without argument creates new random key' do
    application = Application.save(:service_id => '1001',
                                   :id         => '2001',
                                   :state      => :active)

    SecureRandom.expects(:hex).returns('totaly random string')
    key = application.create_key

    assert_equal 'totaly random string', key
    assert_equal [key], application.keys
  end
  
  test '#create_key with argument creates new key with the given value' do
    application = Application.save(:service_id => '1001',
                                   :id         => '2001',
                                   :state      => :active)

    key = application.create_key('foo')

    assert_equal 'foo', key
    assert_equal [key], application.keys
  end

  test 'application has no referrer filters when created' do
    application = Application.save(:service_id => '1001', 
                                   :id         => '2001', 
                                   :state      => :active)

    assert application.referrer_filters.empty?
  end

  test '#create_referrer_filter with blank argument raises an exception' do
    application = Application.save(:service_id => '1001', 
                                   :id         => '2001', 
                                   :state      => :active)


    assert_raise ReferrerFilterInvalid do
      application.create_referrer_filter('')
    end
  end
end
