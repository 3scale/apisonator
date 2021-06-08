require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AuthorizeListAppKeysExtensionTest < Test::Unit::TestCase
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::Extensions

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!
    Memoizer.reset!

    setup_provider_fixtures
    setup_oauth_provider_fixtures_noclobber

    @application = Application.save(service_id: @service.id,
                                    id: next_id,
                                    state: :active,
                                    plan_id: @plan_id,
                                    plan_name: @plan_name)

    @keys = 10.times.map { |i| "key_#{i}" }

    @keys.each do |k|
      @application.create_key k
    end

    @application_oauth = Application.save(service_id: @service_oauth.id,
                                          id: next_id,
                                          state: :active,
                                          plan_id: @plan_id,
                                          plan_name: @plan_name)

    @application_oauth_w_key = Application.save(service_id: @service_oauth.id,
                                                id: next_id,
                                                state: :active,
                                                plan_id: @plan_id,
                                                plan_name: @plan_name)

    @application_oauth_app_key = 'client_secret_which_should_never_really_be_used'
    @application_oauth_w_key.create_key @application_oauth_app_key

    @application_nokeys = Application.save(service_id: @service.id,
                                           id: next_id,
                                           state: :active,
                                           plan_id: @plan_id,
                                           plan_name: @plan_name)

    @application_uk = Application.save(service_id: @service.id,
                                       id: next_id,
                                       state: :active,
                                       plan_id: @plan_id,
                                       plan_name: @plan_name)

    @user_key = 'a_user_key'
    Application.save_id_by_key(@service_id, @user_key, @application_uk.id)
  end

  test 'calling authorize without the list_app_keys extension does not output the application keys section' do
    get '/transactions/authorize.xml',
        { provider_key: @provider_key, service_id: @service.id,
          app_id: @application.id }

    xml_resp = Nokogiri::XML(last_response.body)
    assert_nil xml_resp.at('app_keys')

    get '/transactions/authorize.xml',
        { provider_key: @provider_key, service_id: @service_oauth.id,
          app_id: @application_oauth.id }

    xml_resp = Nokogiri::XML(last_response.body)
    assert_nil xml_resp.at('app_keys')

    get '/transactions/authorize.xml',
        { provider_key: @provider_key, service_id: @service_oauth.id,
          app_id: @application_oauth_w_key.id }

    xml_resp = Nokogiri::XML(last_response.body)
    assert_nil xml_resp.at('app_keys')

    get '/transactions/authorize.xml',
        { provider_key: @provider_key, service_id: @service.id,
          user_key: @user_key }

    xml_resp = Nokogiri::XML(last_response.body)
    assert_nil xml_resp.at('app_keys')
  end

  test 'calling authorize with the list_app_keys extension outputs the application keys section even if no app keys exist' do
    get '/transactions/authorize.xml',
        { provider_key: @provider_key, service_id: @service.id,
          app_id: @application_nokeys.id },
        'HTTP_3SCALE_OPTIONS' => Extensions::LIST_APP_KEYS

    xml_resp = Nokogiri::XML(last_response.body)
    app_keys = xml_resp.at 'app_keys'
    assert_not_nil app_keys
    assert_equal @application_nokeys.id, app_keys['app']
    assert_equal @service.id, app_keys['svc']

    assert_empty xml_resp.search("app_keys key")

    get '/transactions/authorize.xml',
        { provider_key: @provider_key, service_id: @service_oauth.id,
          app_id: @application_oauth.id },
        'HTTP_3SCALE_OPTIONS' => Extensions::LIST_APP_KEYS

    xml_resp = Nokogiri::XML(last_response.body)
    app_keys = xml_resp.at 'app_keys'
    assert_not_nil app_keys
    assert_equal @application_oauth.id, app_keys['app']
    assert_equal @service_oauth.id, app_keys['svc']

    assert_empty xml_resp.search("app_keys key")

    get '/transactions/authorize.xml',
        { provider_key: @provider_key, service_id: @service_oauth.id,
          app_id: @application_oauth_w_key.id },
        'HTTP_3SCALE_OPTIONS' => Extensions::LIST_APP_KEYS

    xml_resp = Nokogiri::XML(last_response.body)
    app_keys = xml_resp.at 'app_keys'
    assert_not_nil app_keys
    assert_equal @application_oauth_w_key.id, app_keys['app']
    assert_equal @service_oauth.id, app_keys['svc']

    keys = xml_resp.search("app_keys key").map { |k| k['id'] }
    assert_not_empty keys
    assert_equal [@application_oauth_app_key], keys

    get '/transactions/authorize.xml',
        { provider_key: @provider_key, service_id: @service.id,
          user_key: @user_key },
        'HTTP_3SCALE_OPTIONS' => Extensions::LIST_APP_KEYS

    xml_resp = Nokogiri::XML(last_response.body)
    app_keys = xml_resp.at 'app_keys'
    assert_not_nil app_keys
    assert_equal @application_uk.id, app_keys['app']
    assert_equal @service.id, app_keys['svc']

    assert_empty xml_resp.search("app_keys key")
  end

  test 'calling authorize with the list_app_keys extension lists the application keys even if no app_key is specified' do
    get '/transactions/authorize.xml',
        { provider_key: @provider_key, service_id: @service.id,
          app_id: @application.id },
        'HTTP_3SCALE_OPTIONS' => Extensions::LIST_APP_KEYS

    xml_resp = Nokogiri::XML(last_response.body)
    app_keys = xml_resp.at 'app_keys'
    assert_not_nil app_keys
    assert_equal @application.id, app_keys['app']
    assert_equal @service.id, app_keys['svc']

    keys = xml_resp.search("app_keys key").map { |n| n[:id] }

    assert_equal @keys.sort, keys.sort
  end

  test 'calling authorize with the list_app_keys extension lists the application keys even if app_key is invalid' do
    get '/transactions/authorize.xml',
        { provider_key: @provider_key, service_id: @service.id,
          app_id: @application.id, app_key: 'invalid-key' },
        'HTTP_3SCALE_OPTIONS' => Extensions::LIST_APP_KEYS

    xml_resp = Nokogiri::XML(last_response.body)
    app_keys = xml_resp.at 'app_keys'
    assert_not_nil app_keys
    assert_equal @application.id, app_keys['app']
    assert_equal @service.id, app_keys['svc']

    keys = xml_resp.search("app_keys key").map { |n| n[:id] }

    assert_equal @keys.sort, keys.sort
  end

  test 'calling authorize with the list_app_keys extension lists the application keys when specifying a valid app_key' do
    get '/transactions/authorize.xml',
        { provider_key: @provider_key, service_id: @service.id,
          app_id: @application.id, app_key: @keys.sample },
        'HTTP_3SCALE_OPTIONS' => Extensions::LIST_APP_KEYS

    xml_resp = Nokogiri::XML(last_response.body)
    app_keys = xml_resp.at 'app_keys'
    assert_not_nil app_keys
    assert_equal @application.id, app_keys['app']
    assert_equal @service.id, app_keys['svc']

    keys = xml_resp.search("app_keys key").map { |n| n[:id] }

    assert_equal @keys.sort, keys.sort
  end

  test "calling authorize with the list_app_keys extension lists a maximum of #{Transactor::Status.const_get(:LIST_APP_KEYS_MAX)} application keys" do
    max_keys = Transactor::Status.const_get :LIST_APP_KEYS_MAX

    (@keys.size + 1).upto(max_keys + 1) do |i|
      @application.create_key "key_#{i}"
    end

    get '/transactions/authorize.xml',
        { provider_key: @provider_key, service_id: @service.id,
          app_id: @application.id, app_key: @keys.sample },
        'HTTP_3SCALE_OPTIONS' => Extensions::LIST_APP_KEYS

    xml_resp = Nokogiri::XML(last_response.body)
    app_keys = xml_resp.at 'app_keys'
    assert_not_nil app_keys
    assert_equal @application.id, app_keys['app']
    assert_equal @service.id, app_keys['svc']

    keys = xml_resp.search("app_keys key").map { |n| n[:id] }

    assert_equal max_keys, keys.size
  end
end
