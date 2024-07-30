require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require '3scale/backend/storage_sync'

class StorageSyncTest < Test::Unit::TestCase
  def test_basic_operations
    storage = StorageSync.instance(true)
    storage.del('foo')
    assert_nil storage.get('foo')
    storage.set('foo', 'bar')
    assert_equal 'bar', storage.get('foo')
  end

  def test_redis_host_and_port
    config_obj = url('127.0.0.1:6379')
    storage = StorageSync.send :new, config_obj
    assert_client_config(config_obj, storage)
  end

  def test_redis_url
    config_obj = url('redis://127.0.0.1:6379/0')
    storage = StorageSync.send :new, config_obj
    assert_client_config(config_obj, storage)
  end

  def test_redis_unix
    config_obj = url('unix:///tmp/redis_unix.6379.sock')
    storage = StorageSync.send :new, config_obj
    assert_client_config(config_obj, storage)
  end

  def test_redis_protected_url
    assert_nothing_raised do
      StorageSync.send :new, url('redis://user:passwd@127.0.0.1:6379/0')
    end
  end

  def test_redis_malformed_url
    assert_raise Storage::InvalidURI do
      StorageSync.send :new, url('a_malformed_url:1:10')
    end
  end

  def test_redis_unknown_scheme
    assert_raise ArgumentError do
      StorageSync.send :new, url('myscheme://127.0.0.1:6379')
    end
  end

  def test_redis_url_without_scheme
    storage = StorageSync.send :new, url('backend-redis')
    assert_client_config({ url: URI('redis://backend-redis:6379') }, storage)
  end

  def test_sentinels_connection_string
    config_obj = {
      url: 'redis://master-group-name',
      sentinels: ',redis://127.0.0.1:26379, ,    , 127.0.0.1:36379,'
    }

    conn = StorageSync.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_config({ url: config_obj[:url],
                           sentinels: [{ host: '127.0.0.1', port: 26_379 },
                                       { host: '127.0.0.1', port: 36_379 }] },
                           conn)
  end

  def test_sentinels_connection_string_escaped
    config_obj = {
      url: 'redis://master-group-name',
      sentinels: 'redis://user:passw\,ord@127.0.0.1:26379 ,127.0.0.1:36379, ,'
    }

    conn = StorageSync.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_config({ url: config_obj[:url],
                           sentinels: [{ host: '127.0.0.1', port: 26_379},
                                       { host: '127.0.0.1', port: 36_379 }],
                           sentinel_username: 'user',
                           sentinel_password: 'passw,ord'},
                           conn)
  end

  def test_sentinels_connection_array_strings
    config_obj = {
      url: 'redis://master-group-name',
      sentinels: ['redis://127.0.0.1:26379 ', ' 127.0.0.1:36379', nil]
    }

    conn = StorageSync.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_config({ url: config_obj[:url],
                           sentinels: [{ host: '127.0.0.1', port: 26_379 },
                                       { host: '127.0.0.1', port: 36_379 }] },
                           conn)
  end

  def test_sentinels_malformed_url
    config_obj = {
      url: 'redis://master-group-name',
      sentinels: 'redis://127.0.0.1:26379,a_malformed_url:1:10'
    }
    assert_raise Storage::InvalidURI do
      StorageSync.send :new, Storage::Helpers.config_with(config_obj)
    end
  end

  def test_sentinels_simple_url
    config_obj = {
      url: 'master-group-name', # url of the sentinel master name conf
      sentinels: 'redis://127.0.0.1:26379'
    }

    conn = StorageSync.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_config({ url: "redis://#{config_obj[:url]}",
                           sentinels: [{ host: '127.0.0.1', port: 26_379 }] },
                           conn)
  end

  def test_sentinels_array_strings_default_port
    default_sentinel_port = Storage::Helpers.singleton_class.const_get(:DEFAULT_SENTINEL_PORT)
    config_obj = {
      url: 'redis://master-group-name',
      sentinels: ['127.0.0.2', 'redis://127.0.0.1',
                  '192.168.1.1', '127.0.0.1:36379',
                  'redis://127.0.0.1:46379']
    }

    conn = StorageSync.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_config({ url: config_obj[:url],
                           sentinels: [{ host: '127.0.0.2', port: default_sentinel_port },
                                       { host: '127.0.0.1', port: default_sentinel_port },
                                       { host: '192.168.1.1', port: default_sentinel_port },
                                       { host: '127.0.0.1', port: 36379 },
                                       { host: '127.0.0.1', port: 46379 }] },
                           conn)
  end

  def test_sentinels_array_strings_password
    config_obj = {
      url: 'redis://master-group-name',
      sentinels: ['redis://:abc@192.168.1.1:3333',
                  '192.168.1.2:4444',
                  'redis://192.168.1.3:5555']
    }

    conn = StorageSync.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_config({ url: config_obj[:url],
                           sentinels: [{ host: '192.168.1.1', port: 3333 },
                                       { host: '192.168.1.2', port: 4444 },
                                       { host: '192.168.1.3', port: 5555 }],
                           sentinel_password: 'abc'},
                           conn)
  end

  def test_sentinels_correct_role
    %i[master slave].each do |role|
      config_obj = {
        url: 'redis://master-group-name',
        sentinels: 'redis://127.0.0.1:26379',
        role: role
      }

      conn = StorageSync.send :new, Storage::Helpers.config_with(config_obj)
      assert_sentinel_config({ url: config_obj[:url],
                             sentinels: [{ host: '127.0.0.1', port: 26_379 }],
                             role: role },
                             conn)
    end
  end

  def test_sentinels_role_empty
    [''.to_sym, '', nil].each do |role|
      config_obj = {
        url: 'redis://master-group-name',
        sentinels: 'redis://127.0.0.1:26379',
        role: role
      }
      redis_cfg = Storage::Helpers.config_with(config_obj)
      refute redis_cfg.key?(:role)
    end
  end

  def test_role_empty_when_sentinels_does_not_exist
    config_obj = {
      url: 'redis://127.0.0.1:6379/0',
      role: :master
    }
    redis_cfg = Storage::Helpers.config_with(config_obj)
    refute redis_cfg.key?(:role)
  end

  def test_sentinels_empty
    [nil, '', ' ', [], [nil], [''], [' ']].each do |sentinels_val|
      config_obj = {
        url: 'redis://master-group-name',
        sentinels: sentinels_val
      }
      redis_cfg = Storage::Helpers.config_with(config_obj)
      refute redis_cfg.key?(:sentinels)
    end
  end

  def test_ssl_from_url
    cfg = Storage::Helpers.config_with({url: 'rediss://localhost:46379' })
    assert cfg[:ssl]
  end

  def test_ssl_from_param
    cfg = Storage::Helpers.config_with({url: 'redis://localhost:46379', ssl: true })
    assert cfg[:ssl]
  end

  def test_ssl_url_precedence
    cfg = Storage::Helpers.config_with({url: 'rediss://localhost:46379', ssl: false })
    assert cfg[:ssl]
  end

  def test_tls_no_client_certificate
    config_obj = {
      url: 'rediss://localhost:46379/0',
      ssl_params: {
        ca_file: File.expand_path(File.join(__FILE__, '..', '..', '..', 'script', 'config', 'ca-root-cert.pem'))
      }
    }
    storage = StorageSync.send :new, Storage::Helpers.config_with(config_obj)
    assert_client_config(config_obj, storage)
  end

  def test_tls_client_cert
    config_obj = {
      url: 'rediss://localhost:46379/0',
      ssl_params: {
        ca_file: File.expand_path(File.join(__FILE__, '..', '..', '..', 'script', 'config', 'ca-root-cert.pem')),
        cert: File.expand_path(File.join(__FILE__, '..', '..', '..', 'script', 'config', 'redis-client.crt')),
        key: File.expand_path(File.join(__FILE__, '..', '..', '..', 'script', 'config', 'redis-client.key'))
      }
    }
    storage = StorageSync.send :new, Storage::Helpers.config_with(config_obj)
    assert_client_config(config_obj, storage)
  end

  def test_acl
    config_obj = {
      url: 'redis://localhost:6379/0',
      username: 'apisonator-test',
      password: 'p4ssW0rd'
    }
    storage = StorageSync.send :new, Storage::Helpers.config_with(config_obj)
    assert_client_config(config_obj, storage)
  end

  def test_acl_tls
    config_obj = {
      url: 'rediss://localhost:46379/0',
      ssl_params: {
        ca_file: File.expand_path(File.join(__FILE__, '..', '..', '..', 'script', 'config', 'ca-root-cert.pem'))
      },
      username: 'apisonator-test',
      password: 'p4ssW0rd'
    }
    storage = StorageSync.send :new, Storage::Helpers.config_with(config_obj)
    assert_client_config(config_obj, storage)
  end

  private

  def assert_client_config(conf, conn)
    config = conn.instance_variable_get(:@inner).instance_variable_get(:@client).instance_variable_get(:@config)

    if conf[:url].to_s.strip.empty?
      assert_equal conf[:path], config.path
    else
      url = URI(conf[:url])
      assert_equal url.host, config.host
      assert_equal url.port, config.port
    end

    assert_equal conf[:username] || 'default', config.username
    assert_equal conf[:password], config.password

    unless conf[:ssl_params].to_s.strip.empty?
      %i[ca_file cert key].each do |key|
        assert_equal conf[:ssl_params][key], config.ssl_params[key]
      end
    end
  end

  def assert_sentinel_config(conf, client)
    config = client.instance_variable_get(:@inner).instance_variable_get(:@client).instance_variable_get(:@config)
    assert config.sentinel?
    assert_equal URI(conf[:url]).host, config.name
    assert_equal conf[:role] || :master, config.instance_variable_get(:@role)
    conf[:sentinels].each_with_index do |s, i|
      assert_equal s[:host], config.sentinels[i].host
      assert_equal s[:port], config.sentinels[i].port
    end
    extra_conf = config.instance_variable_get(:@extra_config)
    assert_equal conf[:sentinel_username], extra_conf[:username]
    assert_equal conf[:sentinel_password], extra_conf[:password]
  end

  def url(url)
    Storage::Helpers.config_with({ url: url })
  end
end
