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
                     plan_name: 'awesome', redirect_url: 'bla')
    application = Application.load('2001', '8010')
    assert application.kind_of?(Application)
    assert_equal '2001', application.service_id
    assert_equal '8010', application.id
    assert_equal :active, application.state
    assert_equal '3001', application.plan_id
    assert_equal 'awesome', application.plan_name
    assert_equal 'bla', application.redirect_url
    # test that memoization of load is invalidated
    Application.save(service_id: '2001', id: '8010', state: :suspended)
    changed_app = Application.load('2001', '8010')
    assert_not_equal application.state, changed_app.state
  end

  test '#save correctly saves an Application instance data' do
    application = Application.new(service_id: '2001', id: '8011',
                     state: :active, plan_id: '3001',
                     plan_name: 'awesome', redirect_url: 'bla')
    application.save
    assert_equal '2001', application.service_id
    assert_equal '8011', application.id
    assert_equal :active, application.state
    assert_equal '3001', application.plan_id
    assert_equal 'awesome', application.plan_name
    assert_equal 'bla', application.redirect_url
    # test for change
    application.plan_name = 'almost_awesome'
    application.save
    newapp = Application.load('2001', '8011')
    assert_equal 'almost_awesome', newapp.plan_name
  end

  test '#save raises an exception if no state is defined' do
    assert_raise ApplicationHasNoState do
      Application.save(service_id: '2001', id: '8011',
                       plan_id: '3001', plan_name: 'awesome',
                       redirect_url: 'bla')
    end
  end

  test '.load correctly creates an Application instance' do
    Application.save(service_id: '2001', id: '8012',
                     state: :active, redirect_url: 'bla')
    application = Application.load('2001', '8012')
    assert application.kind_of?(Application)
    assert_equal '2001', application.service_id
    assert_equal '8012', application.id
    assert_equal :active, application.state
    assert_equal nil, application.plan_id
    assert_equal nil, application.plan_name
    assert_equal 'bla', application.redirect_url
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

    assert_raise ApplicationNotFound do
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

  test 'remove application keys test' do
    application = Application.save(:service_id => '1001',
                                   :id         => '2001',
                                   :state      => :active)

    key_foo = application.create_key('foo')
    assert_equal 'foo', key_foo

    key_bar = application.create_key('bar')
    assert_equal 'bar', key_bar

    assert_equal [key_foo, key_bar].sort, application.keys.sort

    application.delete_key(key_foo)

    assert_equal [key_bar], application.keys
  end

  test '#keys returns keys member set' do
    application = Application.save(service_id: '1001',
                                   id: '2001',
                                   state: :active)

    keys = ['fry', 'bender', 'leela']
    keys.each { |key| application.create_key(key) }

    assert_equal keys.sort, application.keys.sort
  end

  test '#has_keys? checks whether keys set is not empty' do
    application = Application.save(service_id: '1001',
                                   id: '2001',
                                   state: :active)

    assert !application.has_keys?

    application.create_key('fry')

    assert application.has_keys?
  end

  test '#has_no_keys? checks whether keys set is empty' do
    application = Application.save(service_id: '1001',
                                   id: '2001',
                                   state: :active)

    assert application.has_no_keys?

    application.create_key('fry')

    assert !application.has_no_keys?
  end

  test '#has_key? checks whether member exists in keys set' do
    application = Application.save(service_id: '1001',
                                   id: '2001',
                                   state: :active)

    application.create_key('fry')

    assert application.has_key?('fry')
    assert !application.has_key?('other')
  end

  test '#referrer_filters returns referrer_filters member set' do
    application = Application.save(service_id: '1001',
                                   id: '2001',
                                   state: :active)

    filters = ['fry', 'bender', 'leela']
    filters.each { |f| application.create_referrer_filter(f) }

    assert_equal filters.sort, application.referrer_filters.sort
  end

  test '#has_referrer_filters? checks whether referrer_filters set is not empty' do
    application = Application.save(service_id: '1001',
                                   id: '2001',
                                   state: :active)
    assert !application.has_referrer_filters?

    application.create_referrer_filter('fry')

    assert application.has_referrer_filters?
  end

  test '.load_usage_limits_affected_by only loads the limits affected by the metrics passed' do
    service_id = '1001'
    plan_id = '2001'
    metric_1_id = '3001'
    metric_2_id = '3002'
    metric_3_id = '3003'
    metric_4_id = '3004'
    metric_5_id = '3005'
    metric_ids = [metric_1_id, metric_2_id, metric_3_id, metric_4_id, metric_5_id]

    # Create 5 metrics: m1, m2, m3, m4, m5.
    # m1 is a parent of m2 and m3 is a parent of m4.
    [
      Metric.new(service_id: service_id, id: metric_1_id, name: 'm1', children: [
        Metric.new(service_id: service_id, id: metric_2_id, name: 'm2')
      ]),
      Metric.new(service_id: service_id, id: metric_3_id, name: 'm3', children: [
        Metric.new(service_id: service_id, id: metric_4_id, name: 'm4')
      ]),
      Metric.new(service_id: service_id, id: metric_5_id, name: 'm5')
    ].each(&:save)

    # Create 2 limits for m1, and 1 for the rest of metrics.
    UsageLimit.save(service_id: service_id, plan_id: plan_id, metric_id: metric_1_id, month: 100)
    metric_ids.each do |metric_id|
      UsageLimit.save(service_id: service_id, plan_id: plan_id, metric_id: metric_id, day: 10)
    end

    application = Application.save(
      service_id: service_id, id: '4000', state: :active, plan_id: plan_id, plan_name: 'some_plan'
    )

    # When passing m2 and m3, we should also get the limits that apply to m1,
    # because it's a parent of m2.
    application.load_usage_limits_affected_by(['m2', 'm3'])
    assert_equal 4, application.usage_limits.count
    assert_equal 2, application.usage_limits.count { |limit| limit.metric_id == metric_1_id }
    assert_equal 1, application.usage_limits.count { |limit| limit.metric_id == metric_2_id }
    assert_equal 1, application.usage_limits.count { |limit| limit.metric_id == metric_3_id }
  end

  test '.load_usage_limits_affected_by raises MetricInvalid when a metric does not exist' do
    application = Application.save(
      service_id: '1000', id: '2000', state: :active, plan_id: '3000', plan_name: 'some_plan'
    )

    assert_raise MetricInvalid do
      application.load_usage_limits_affected_by(['non_existing'])
    end
  end
end
