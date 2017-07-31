require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class UserTest < Test::Unit::TestCase
  include TestHelpers::Sequences

  def storage
    @storage ||= Storage.instance(true)
  end

  def setup
    storage.flushdb
  end

  def test_create_user_errors
    service = Service.save! :provider_key => 'foo', :id => 7001001

    assert_raise ServiceRequiresRegisteredUser do
      User.load_or_create!(service, 'username1')
    end

    assert_raise UserRequiresDefinedPlan do
      User.save!(:username => 'username', :service_id => '7001001')
    end

    assert_raise UserRequiresUsername do
      User.save!(:service_id => '7001')
    end

    assert_raise UserRequiresServiceId do
      User.save!(:username => 'username')
    end

    assert_raise UserRequiresValidService do
      User.save!(:username => 'username', :service_id => '7001001001')
    end
  end

  def test_create_user_successful_service_require_registered_users
    service = Service.save!(provider_key: 'foo', id: '7002')
    User.save! username: 'username', service_id: '7002', plan_id: '1001',
      plan_name: 'planname'
    user = User.load(service.id, 'username')

    assert_equal true, user.active?
    assert_equal 'username', user.username
    assert_equal 'planname', user.plan_name
    assert_equal '1001', user.plan_id
    assert_equal '7002', user.service_id

    User.delete! service.id, user.username

    assert_raise ServiceRequiresRegisteredUser do
      user = User.load_or_create!(service, 'username')
    end
  end

  def test_create_user_successful_service_not_require_registered_users
    service = Service.save!(provider_key: 'foo', id: '7001',
                            user_registration_required: false,
                            default_user_plan_name: 'planname',
                            default_user_plan_id: '1001')

    names = %w(username0 username1 username2 username3 username4 username5)
    names.each_with_index do |username, idx|
      user = User.load_or_create!(service, username)

      assert_equal true, user.active?
      assert_equal username, user.username
      assert_equal service.default_user_plan_name, user.plan_name
      assert_equal service.default_user_plan_id, user.plan_id
      assert_equal service.id, user.service_id
    end
  end

  test '#metric_names returns loaded metric names' do
    service_id = next_id
    plan_id = next_id
    metric_id = next_id
    metric_name = 'hits'
    service = Service.save!(provider_key: 'foo', id: service_id,
                            user_registration_required: false,
                            default_user_plan_name: 'user_plan_name',
                            default_user_plan_id: plan_id)

    user = User.load_or_create!(service, 'user_1')

    Metric.save(service_id: service_id, id: metric_id, name: metric_name)
    UsageLimit.save(service_id: service_id,
                    plan_id: plan_id,
                    metric_id: metric_id,
                    minute: 10)

    # No metrics loaded
    assert_empty user.metric_names

    user.metric_name(metric_id)
    assert_equal({ metric_id => metric_name }, user.metric_names)
  end

  test '#load_metric_names loads and returns the names of all the metrics for '\
       'which there is a usage limit that applies to the app' do
    service_id = next_id
    plan_id = next_id
    metrics = { next_id => 'metric1', next_id => 'metric2' }
    service = Service.save!(provider_key: 'foo', id: service_id,
                            user_registration_required: false,
                            default_user_plan_name: 'user_plan_name',
                            default_user_plan_id: plan_id)

    user = User.load_or_create!(service, 'user_1')

    metrics.each do |metric_id, metric_name|
      Metric.save(service_id: service_id, id: metric_id, name: metric_name)
      UsageLimit.save(service_id: service_id,
                      plan_id: plan_id,
                      metric_id: metric_id,
                      minute: 10)
    end

    assert_equal metrics, user.load_metric_names
  end
end
