require File.dirname(__FILE__) + '/../test_helper'

class ApplicationTest < Test::Unit::TestCase
  def setup
    @storage = Storage.instance(true)
    @storage.flushdb
  end

  def test_active_returns_true_if_application_is_in_active_state
    application = Application.new(:state => :active)
    assert application.active?
  end

  def test_active_returns_false_if_application_is_in_suspended_state
    application = Application.new(:state => :suspended)
    assert !application.active?
  end

  def test_application_has_no_keys_when_created
    application = Application.save(:service_id => '1001', 
                                   :id         => '2001', 
                                   :state      => :active)

    assert_equal nil, @storage.smembers('application/service_id:1001/id:2001/keys')
  end

  def test_keys_is_empty_if_there_are_no_keys
    application = Application.save(:service_id => '1001', 
                                   :id         => '2001', 
                                   :state      => :active)

    assert application.keys.empty?
  end

  def test_keys_returns_stored_keys
    application = Application.save(:service_id => '1001', 
                                   :id         => '2001', 
                                   :state      => :active)

    @storage.sadd('application/service_id:1001/id:2001/keys', 'foo')
    @storage.sadd('application/service_id:1001/id:2001/keys', 'bar')

    assert_equal ['bar', 'foo'], application.keys.sort
  end
  
  def test_keys_empty_question_mark_returns_true_if_there_are_no_keys
    application = Application.save(:service_id => '1001', 
                                   :id         => '2001', 
                                   :state      => :active)

    assert application.keys_empty?
  end
  
  def test_keys_empty_question_mark_returns_false_if_there_are_stored_keys
    application = Application.save(:service_id => '1001', 
                                   :id         => '2001', 
                                   :state      => :active)
    application.create_key!    

    assert !application.keys_empty?
  end

  def test_create_key_bang_without_argument_creates_new_random_key
    application = Application.save(:service_id => '1001',
                                   :id         => '2001',
                                   :state      => :active)

    SecureRandom.expects(:hex).returns('totaly random string')
    key = application.create_key!

    assert_equal 'totaly random string', key
    assert_equal [key], application.keys
  end
  
  def test_create_key_bang_with_argument_creates_new_key_with_the_given_value
    application = Application.save(:service_id => '1001',
                                   :id         => '2001',
                                   :state      => :active)

    key = application.create_key!('foo')

    assert_equal 'foo', key
    assert_equal [key], application.keys
  end

  def test_has_key_question_mark_returns_true_only_if_application_has_the_given_key
    application = Application.save(:service_id => '1001',
                                   :id         => '2001',
                                   :state      => :active)
    key_one = application.create_key!
    key_two = application.create_key!

    assert  application.has_key?(key_one)
    assert  application.has_key?(key_two)
    assert !application.has_key?('invalid')
  end
end
