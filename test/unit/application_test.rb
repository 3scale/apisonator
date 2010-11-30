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
    Application.save(:service_id => '1001', :id => '2001', :state => :active)

    application = Application.load!('1001', '2001')

    assert_not_nil application
    assert_equal '1001',  application.service_id
    assert_equal '2001',  application.id
    assert_equal :active, application.state
  end

  test 'load_by_id_or_user_key! returns application by id if it exists' do
    Application.save(:service_id => '1001', :id => '2001', :state => :active)

    application = Application.load_by_id_or_user_key!('1001', '2001', nil)
    assert_equal '1001',  application.service_id
    assert_equal '2001',  application.id
    assert_equal :active, application.state
  end

  test 'load_by_id_or_user_key! returns application by user_key if it exists' do
    Application.save(:service_id => '1001', :id => '2001', :state => :active)
    Application.save_id_by_key('1001', 'foobar', '2001')

    application = Application.load_by_id_or_user_key!('1001', nil, 'foobar')
    assert_equal '1001',  application.service_id
    assert_equal '2001',  application.id
    assert_equal :active, application.state
  end

  test 'load_by_id_or_user_key! raises an exception if id is invalid' do
    assert_raise ApplicationNotFound do
      Application.load_by_id_or_user_key!('1001', '2001', nil)
    end
  end

  test 'load_by_id_or_user_key! raises an exception if user_key is invalid' do
    assert_raise UserKeyInvalid do
      Application.load_by_id_or_user_key!('1001', nil, 'foobar')
    end
  end

  test 'load_by_id_or_user_key! raises an exception if key-to-id mapping exists, but application does not' do
    Application.save_id_by_key('1001', 'foobar', '2001')

    assert_raise UserKeyInvalid do
      Application.load_by_id_or_user_key!('1001', nil, 'foobar')
    end
  end

  test 'load_by_id_or_user_key! raises an exception if both application id and user key are passed' do
    Application.save(:service_id => '1001', :id => '2001', :state => :active)
    Application.save_id_by_key('1001', 'foobar', '2001')

    assert_raise AuthenticationError do
      Application.load_by_id_or_user_key!('1001', '2001', 'foobar')
    end
  end

  test 'load_by_id_or_user_key! raises an exception if neither application id, nor user key is passed' do
    assert_raise ApplicationNotFound do
      Application.load_by_id_or_user_key!('1001', nil, nil)
    end
  end

  test 'extract_id! returns application id if valid application id passed' do
    Application.save(:service_id => '1001', :id => '2001', :state => :active)

    assert_equal '2001', Application.extract_id!('1001', '2001', nil)
  end

  test 'extract_id! returns application id if valid user key passed' do
    Application.save(:service_id => '1001', :id => '2001', :state => :active)
    Application.save_id_by_key('1001', 'foobar', '2001')

    assert_equal '2001', Application.extract_id!('1001', nil, 'foobar')
  end

  test 'extract_id! raises an exception if application id is invalid' do
    assert_raise ApplicationNotFound do
      Application.extract_id!('1001', '2001', nil)
    end
  end

  test 'extract_id! raises an exception if user key is invalid' do
    assert_raise UserKeyInvalid do
      Application.extract_id!('1001', nil, 'foobar')
    end
  end

  test 'extract_id! raises an exception if key-to-id mapping exists, but application does not' do
    Application.save_id_by_key('1001', 'foobar', '2001')

    assert_raise UserKeyInvalid do
      Application.extract_id!('1001', nil, 'foobar')
    end
  end

  test 'extract_id! raises an exception if both application id and user key are passed' do
    Application.save(:service_id => '1001', :id => '2001', :state => :active)
    Application.save_id_by_key('1001', 'foobar', '2001')

    assert_raise AuthenticationError do
      Application.extract_id!('1001', '2001', 'foobar')
    end
  end

  test 'extract_id! raises an exception if neither application id, nor user key is passed' do
    assert_raise ApplicationNotFound do
      Application.extract_id!('1001', nil, nil)
    end
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
