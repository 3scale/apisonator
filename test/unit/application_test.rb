require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class ApplicationTest < Test::Unit::TestCase

  ##include TestHelpers::Integration
  include TestHelpers::Sequences

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb
    Memoizer.reset!
  end

  test '.save correctly saves an application' do
    Application.save(service_id: '2001', id: '8010',
                     state: :active, plan_id: '3001',
                     plan_name: 'awesome', redirect_url: 'bla',
                     version: '666')
    application = Application.load('2001', '8010')
    assert application.kind_of?(Application)
    assert_equal '2001', application.service_id
    assert_equal '8010', application.id
    assert_equal :active, application.state
    assert_equal '3001', application.plan_id
    assert_equal 'awesome', application.plan_name
    assert_equal 'bla', application.redirect_url
    assert_equal '1', application.version
    # test that memoization of load is invalidated
    Application.save(service_id: '2001', id: '8010', state: :suspended)
    changed_app = Application.load('2001', '8010')
    assert_not_equal application.state, changed_app.state
  end

  test '#save correctly saves an Application instance data' do
    application = Application.new(service_id: '2001', id: '8011',
                     state: :active, plan_id: '3001',
                     plan_name: 'awesome', redirect_url: 'bla',
                     version: '666')
    application.save
    assert_equal '2001', application.service_id
    assert_equal '8011', application.id
    assert_equal :active, application.state
    assert_equal '3001', application.plan_id
    assert_equal 'awesome', application.plan_name
    assert_equal 'bla', application.redirect_url
    assert_equal '1', application.version
    # test for change and version increment
    application.plan_name = 'almost_awesome'
    application.save
    newapp = Application.load('2001', '8011')
    assert_equal 'almost_awesome', newapp.plan_name
    assert_equal '2', newapp.version
  end

  test '.load correctly creates an Application instance' do
    Application.save(service_id: '2001', id: '8012',
                     state: :active, redirect_url: 'bla',
                     version: '666')
    application = Application.load('2001', '8012')
    assert application.kind_of?(Application)
    assert_equal '2001', application.service_id
    assert_equal '8012', application.id
    assert_equal :active, application.state
    assert_equal nil, application.plan_id
    assert_equal nil, application.plan_name
    assert_equal 'bla', application.redirect_url
    assert_equal '1', application.version
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

  test '.exists? returns true if an Application exists' do
    Application.save(service_id: '4088', id: '5088', state: :suspended)
    assert Application.exists?('4088', '5088')
  end

  test '.exists? returns false if an Application does not exist' do
    Application.delete('4088', '5088') rescue nil
    assert !Application.exists?('4088', '5088')
  end

  test '.delete deletes an Application correctly' do
    Application.save(service_id: '8010', id: '2011', state: :active)
    # load used to memoize the app so that invalidation is tested
    assert_not_nil Application.load('8010', '2011')
    Application.delete('8010', '2011')
    assert_nil Application.load('8010', '2011')
  end

  test 'save_id_by_key and load_id_by_key returns the correct Application ID' do
    Application.save_id_by_key('1001', 'some_key', '2001')
    assert_equal '2001', Application.load_id_by_key('1001', 'some_key')
    # test that memoization of load_id_by_key is invalidated
    Application.save_id_by_key('1001', 'some_key', '2002')
    assert_equal '2002', Application.load_id_by_key('1001', 'some_key')
  end

  test 'save_id_by_key raises if it receives blank parameters' do
    assert_raise ApplicationHasInconsistentData do
      Application.save_id_by_key('', 'some_key', '2001')
    end

    assert_raise ApplicationHasInconsistentData do
      Application.save_id_by_key(nil, 'some_key', '2001')
    end

    assert_raise ApplicationHasInconsistentData do
      Application.save_id_by_key('1001', '', '2001')
    end

    assert_raise ApplicationHasInconsistentData do
      Application.save_id_by_key('1001', nil, '2001')
    end

    assert_raise ApplicationHasInconsistentData do
      Application.save_id_by_key('1001', 'some_key', '')
    end

    assert_raise ApplicationHasInconsistentData do
      Application.save_id_by_key('1001', 'some_key', nil)
    end
  end

  test 'delete_id_by_key deletes correctly a key' do
    Application.save_id_by_key('1001', 'some_key', '2001')
    assert_equal '2001', Application.load_id_by_key('1001', 'some_key')
    Application.delete_id_by_key('1001', 'some_key')
    assert_nil Application.load_id_by_key('1001', 'some_key')
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

    assert_raise ApplicationNotFound do
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

    assert_equal '2001', Application.extract_id!('1001', '2001', nil, nil)
  end

  test 'extract_id! returns application id if valid user key passed' do
    Application.save(:service_id => '1001', :id => '2001', :state => :active)
    Application.save_id_by_key('1001', 'foobar', '2001')

    assert_equal '2001', Application.extract_id!('1001', nil, 'foobar', nil)
  end

  test 'extract_id! raises an exception if application id is invalid' do
    assert_raise ApplicationNotFound do
      Application.extract_id!('1001', '2001', nil, nil)
    end
  end

  test 'extract_id! raises an exception if user key is invalid' do
    assert_raise UserKeyInvalid do
      Application.extract_id!('1001', nil, 'foobar', nil)
    end
  end

  test 'extract_id! raises an exception if key-to-id mapping exists, but application does not' do
    Application.save_id_by_key('1001', 'foobar', '2001')

    assert_raise ApplicationNotFound do
      Application.extract_id!('1001', nil, 'foobar', nil)
    end
  end

  test 'extract_id! raises an exception if both application id and user key are passed' do
    Application.save(:service_id => '1001', :id => '2001', :state => :active)
    Application.save_id_by_key('1001', 'foobar', '2001')

    assert_raise AuthenticationError do
      Application.extract_id!('1001', '2001', 'foobar', nil)
    end
  end

  test 'extract_id! raises an exception if neither application id, nor user key is passed, nor access_token' do
    assert_raise ApplicationNotFound do
      Application.extract_id!('1001', nil, nil, nil)
    end
  end

  test 'extract_id! handles access_token' do

    Application.save(:service_id => '1001', :id => '2001', :state => :active)
    OAuth::Token::Storage.create('token', '1001', '2001', nil)
    assert_equal '2001', Application.extract_id!('1001', nil, nil, 'token')

  end

  test 'extract_id! fails when access token is not mapped to an app_id' do

     Application.save(:service_id => '1001', :id => '2001', :state => :active)
     OAuth::Token::Storage.create('token', '1001', '2001', nil)

     assert_raise AccessTokenInvalid do
       Application.extract_id!('1001', nil, nil, 'fake-token')
     end

  end

  test 'extract_id! fails when access token is mapped to an app_id that does not exist' do

     Application.save(:service_id => '1001', :id => '2001', :state => :active)
     OAuth::Token::Storage.create('token', '1001', 'fake', nil)

     assert_raise ApplicationNotFound do
       Application.extract_id!('1001', nil, nil, 'token')
     end

  end

  test 'extract_id! app_id takes precedence to access_token' do

    Application.save(:service_id => '1001', :id => '2001', :state => :active)
    Application.save(:service_id => '1001', :id => '3001', :state => :active)

    assert OAuth::Token::Storage.create('token', '1001', '3001', nil)

    assert_equal '3001', Application.extract_id!('1001', nil, nil, 'token')

    assert_equal '2001', Application.extract_id!('1001', '2001', nil, 'token')

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

    ## need to flush the memoizer because keys have been created
    Memoizer.reset!

    assert_equal 'foo', key
    assert_equal [key], application.keys
  end

  test '#metric_names returns loaded metric names' do
    service_id = '1001'
    metric_id = next_id
    metric_name = 'hits'
    plan_id = next_id

    application = Application.save(service_id: service_id,
                                   id: next_id,
                                   state: :active,
                                   plan_id: plan_id)

    Metric.save(service_id: service_id, id: metric_id, name: metric_name)
    UsageLimit.save(service_id: service_id,
                    plan_id: plan_id,
                    metric_id: metric_id,
                    minute: 10)

    # No metrics loaded
    assert_empty application.metric_names

    application.metric_name(metric_id)
    assert_equal({ metric_id => metric_name }, application.metric_names)
  end

  test '#load_metric_names loads and returns the names of all the metrics for '\
       'which there is a usage limit that applies to the app' do
    service_id = '1001'
    plan_id = next_id
    metrics = { next_id => 'metric1', next_id => 'metric2' }

    application = Application.save(service_id: service_id,
                                   id: next_id,
                                   state: :active,
                                   plan_id: plan_id)

    metrics.each do |metric_id, metric_name|
      Metric.save(service_id: service_id, id: metric_id, name: metric_name)
      UsageLimit.save(service_id: service_id,
                      plan_id: plan_id,
                      metric_id: metric_id,
                      minute: 10)
    end

    assert_equal metrics, application.load_metric_names
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

  test 'check version' do

    application = Application.save(:service_id => '1001',
                                   :id         => '2001',
                                   :state      => :active)

    version_app = Application.get_version(application.service_id, application.id)

    application.create_referrer_filter('192.*')
    assert_equal (version_app.to_i+1).to_s, Application.get_version(application.service_id, application.id)
    assert_equal 1, application.size_referrer_filters

    application.delete_referrer_filter('192.*')
    assert_equal (version_app.to_i+2).to_s, Application.get_version(application.service_id, application.id)
    assert_equal 0, application.size_referrer_filters

    key = application.create_key
    assert_not_nil key
    assert_equal (version_app.to_i+3).to_s, Application.get_version(application.service_id, application.id)
    assert_equal 1, application.size_keys

    application.delete_key(key)
    assert_equal (version_app.to_i+4).to_s, Application.get_version(application.service_id, application.id)
    assert_equal 0, application.size_keys

    key = application.create_key('key1')
    assert_equal  'key1', key
    assert_equal (version_app.to_i+5).to_s, Application.get_version(application.service_id, application.id)
    assert_equal 1, application.size_keys

    application.delete_key(key)
    assert_equal (version_app.to_i+6).to_s, Application.get_version(application.service_id, application.id)
    assert_equal 0, application.size_keys

  end

  test 'remove application keys test' do
    application = Application.save(:service_id => '1001',
                                   :id         => '2001',
                                   :state      => :active)

    key_foo = application.create_key('foo')
    assert_equal 'foo', key_foo

    key_bar = application.create_key('bar')
    assert_equal 'bar', key_bar

    ## need to flush the memoizer because keys have been created
    Memoizer.reset!

    assert_equal [key_foo, key_bar].sort, application.keys.sort

    application.delete_key(key_foo)

    ## need to flush the memoizer because keys have been created
    Memoizer.reset!

    assert_equal [key_bar], application.keys

  end

end
