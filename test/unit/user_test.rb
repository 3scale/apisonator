require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class UserTest < Test::Unit::TestCase
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
end
