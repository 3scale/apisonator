require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require '3scale/backend/storage_async'

class StorageAsyncTest < Test::Unit::TestCase
  def test_basic_operations
    storage = StorageAsync::Client.instance(true)
    storage.del('foo')
    assert_nil storage.get('foo')
    storage.set('foo', 'bar')
    assert_equal 'bar', storage.get('foo')
  end

  def test_redis_host_and_port
    storage = StorageAsync::Client.send :new, url('127.0.0.1:6379')
    assert_connection(storage)
  end

  def test_redis_url
    storage = StorageAsync::Client.send :new, url('redis://127.0.0.1:6379/0')
    assert_connection(storage)
  end

  def test_redis_protected_url
    assert_nothing_raised do
      StorageAsync::Client.send :new, url('redis://user:passwd@127.0.0.1:6379/0')
    end
  end

  def test_redis_malformed_url
    assert_raise Storage::InvalidURI do
      StorageAsync::Client.send :new, url('a_malformed_url:1:10')
    end
  end

  def test_sentinels_connection_string
    config_obj = {
      url: 'redis://master-group-name',
      sentinels: ',redis://127.0.0.1:26379, ,    , 127.0.0.1:36379,'
    }

    conn = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_client(conn)
    assert_sentinel_config(conn, url: config_obj[:url],
                         sentinels: [{ host: '127.0.0.1', port: 26_379 },
                                     { host: '127.0.0.1', port: 36_379 }])
  end

  def test_sentinels_connection_array_strings
    config_obj = {
      url: 'redis://master-group-name',
      sentinels: ['redis://127.0.0.1:26379 ', ' 127.0.0.1:36379', nil]
    }

    conn = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_client(conn)
    assert_sentinel_config(conn, url: config_obj[:url],
                         sentinels: [{ host: '127.0.0.1', port: 26_379 },
                                     { host: '127.0.0.1', port: 36_379 }])
  end

  def test_sentinels_connection_array_hashes
    config_obj = {
      url: 'redis://master-group-name',
      sentinels: [{ host: '127.0.0.1', port: 26_379 },
                  {},
                  { host: '127.0.0.1', port: 36_379 },
                  nil]
    }

    conn = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_client(conn)
    assert_sentinel_config(conn, url: config_obj[:url],
                         sentinels: config_obj[:sentinels].compact.reject(&:empty?))
  end

  def test_sentinels_malformed_url
    config_obj = {
      url: 'redis://master-group-name',
      sentinels: 'redis://127.0.0.1:26379,a_malformed_url:1:10'
    }
    assert_raise Storage::InvalidURI do
      StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
    end
  end

  def test_sentinels_simple_url
    config_obj = {
      url: 'master-group-name', # url of the sentinel master name conf
      sentinels: 'redis://127.0.0.1:26379'
    }

    conn = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_client(conn)
    assert_sentinel_config(conn, url: "redis://#{config_obj[:url]}",
                         sentinels: [{ host: '127.0.0.1', port: 26_379 }])
  end

  def test_sentinels_array_hashes_default_port
    default_sentinel_port = Storage::Helpers.singleton_class.const_get(:DEFAULT_SENTINEL_PORT)
    config_obj = {
      url: 'redis://master-group-name',
      sentinels: [{ host: '127.0.0.1' }, { host: '192.168.1.1' },
                  { host: '192.168.1.2', port: nil },
                  { host: '127.0.0.1', port: 36379 }]
    }

    conn = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_client(conn)
    assert_sentinel_config(conn, url: config_obj[:url],
                         sentinels: [{ host: '127.0.0.1', port: default_sentinel_port },
                                     { host: '192.168.1.1', port: default_sentinel_port },
                                     { host: '192.168.1.2', port: default_sentinel_port },
                                     { host: '127.0.0.1', port: 36379 }])
  end

  def test_sentinels_array_strings_default_port
    default_sentinel_port = Storage::Helpers.singleton_class.const_get(:DEFAULT_SENTINEL_PORT)
    config_obj = {
      url: 'redis://master-group-name',
      sentinels: ['127.0.0.2', 'redis://127.0.0.1',
                  '192.168.1.1', '127.0.0.1:36379',
                  'redis://127.0.0.1:46379']
    }

    conn = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_client(conn)
    assert_sentinel_config(conn, url: config_obj[:url],
                         sentinels: [{ host: '127.0.0.2', port: default_sentinel_port },
                                     { host: '127.0.0.1', port: default_sentinel_port },
                                     { host: '192.168.1.1', port: default_sentinel_port },
                                     { host: '127.0.0.1', port: 36379 },
                                     { host: '127.0.0.1', port: 46379 }])
  end

  def test_sentinels_correct_role
    %i[master slave].each do |role|
      config_obj = {
        url: 'redis://master-group-name',
        sentinels: 'redis://127.0.0.1:26379',
        role: role
      }

      conn = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
      assert_sentinel_client(conn)
      assert_sentinel_config(conn, url: config_obj[:url],
                           sentinels: [{ host: '127.0.0.1', port: 26_379 }],
                           role: role)
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
    ['', []].each do |sentinels_val|
      config_obj = {
        url: 'redis://master-group-name',
        sentinels: sentinels_val
      }
      redis_cfg = Storage::Helpers.config_with(config_obj)
      refute redis_cfg.key?(:sentinels)
    end
  end

  def test_redis_no_scheme
    assert_nothing_raised do
      StorageAsync::Client.send :new, url('backend-redis:6379')
    end
  end

  def test_redis_unknown_scheme
    assert_raise ArgumentError do
      StorageAsync::Client.send :new, url('myscheme://127.0.0.1:6379')
    end
  end

  def test_tls_no_client_certificate
    config_obj = {
      url: 'rediss://localhost:46379/0',
      ssl_params: {
        ca_file: File.expand_path(File.join(__FILE__, '..', '..', '..', 'script', 'config', 'ca-root-cert.pem'))
      }
    }
    storage = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
    assert_connection(storage)
  end

  def test_tls_client_cert_rsa
    config_obj = {
      url: 'rediss://localhost:46379/0',
      ssl_params: {
        ca_file: File.expand_path(File.join(__FILE__, '..', '..', '..', 'script', 'config', 'ca-root-cert.pem')),
        cert: File.expand_path(File.join(__FILE__, '..', '..', '..', 'script', 'config', 'redis-client.crt')),
        key: File.expand_path(File.join(__FILE__, '..', '..', '..', 'script', 'config', 'redis-client.key'))
      }
    }
    storage = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
    assert_connection(storage)
  end

  def test_tls_client_cert_dsa
    config_obj = {
      url: 'rediss://localhost:46379/0',
      ssl_params: {
        ca_file: File.expand_path(File.join(__FILE__, '..', '..', '..', 'script', 'config', 'ca-root-cert.pem')),
        cert: File.expand_path(File.join(__FILE__, '..', '..', '..', 'script', 'config', 'redis-dsa.crt')),
        key: File.expand_path(File.join(__FILE__, '..', '..', '..', 'script', 'config', 'redis-dsa.pem'))
      }
    }
    storage = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
    assert_connection(storage)
  end

  def test_tls_client_cert_ec
    config_obj = {
      url: 'rediss://localhost:46379/0',
      ssl_params: {
        ca_file: File.expand_path(File.join(__FILE__, '..', '..', '..', 'script', 'config', 'ca-root-cert.pem')),
        cert: File.expand_path(File.join(__FILE__, '..', '..', '..', 'script', 'config', 'redis-ec.crt')),
        key: File.expand_path(File.join(__FILE__, '..', '..', '..', 'script', 'config', 'redis-ec.key'))
      }
    }
    storage = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
    assert_connection(storage)
  end

  def test_acl
    config_obj = {
      url: 'redis://localhost:6379/0',
      username: 'apisonator-test',
      password: 'p4ssW0rd'
    }
    storage = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
    assert_connection(storage)
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
    storage = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
    assert_connection(storage)
  end

  private

  def assert_connection(client)
    client.flushdb
    client.set('foo', 'bar')
    assert_equal 'bar', client.get('foo')
  end

  def assert_sentinel_client(client)
    inner_client = client.instance_variable_get(:@redis_async)
    assert_instance_of Async::Redis::SentinelsClient, inner_client
  end

  def assert_sentinel_config(conn, url:, **conf)
    client = conn.instance_variable_get(:@redis_async)
    uri = URI(url || '')
    name = uri.host
    role = conf[:role] || :master
    password = client.instance_variable_get(:@protocol).instance_variable_get(:@password)

    assert_equal name, client.instance_variable_get(:@master_name)
    assert_equal role, client.instance_variable_get(:@role)

    assert_equal conf[:sentinels].size, client.instance_variable_get(:@sentinel_endpoints).size
    client.instance_variable_get(:@sentinel_endpoints).each_with_index do |endpoint, i|
      host, port = endpoint.address
      assert_equal conf[:sentinels][i][:host], host
      assert_equal conf[:sentinels][i][:port], port
      assert_equal(conf[:sentinels][i][:password], password) if conf[:sentinels][i].key? :password
    end unless conf[:sentinels].empty?
  end

  def url(url)
    Storage::Helpers.config_with({ url: url })
  end
end
