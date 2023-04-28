require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class StorageTest < Test::Unit::TestCase
  def test_basic_operations
    storage = StorageSync.instance(true)
    storage.del('foo')
    assert_nil storage.get('foo')
    storage.set('foo', 'bar')
    assert_equal 'bar', storage.get('foo')
  end

  def test_redis_host_and_port
    storage = StorageSync.send :new, url('127.0.0.1:6379')
    assert_connection(storage)
  end

  def test_redis_url
    storage = StorageSync.send :new, url('redis://127.0.0.1:6379/0')
    assert_connection(storage)
  end

  def test_redis_unix
    storage = StorageSync.send :new, url('unix:///tmp/redis_unix.6379.sock')
    assert_connection(storage)
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

  def test_redis_url_without_scheme
    assert_nothing_raised do
      StorageSync.send :new, url('foo')
    end
  end

  def test_sentinels_connection_string
    config_obj = {
      url: 'redis://master-group-name',
      sentinels: ',redis://127.0.0.1:26379, ,    , 127.0.0.1:36379,'
    }

    conn = StorageSync.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_connector(conn)
    assert_client_config(conn, url: config_obj[:url],
                               sentinels: [{ host: '127.0.0.1', port: 26_379 },
                                           { host: '127.0.0.1', port: 36_379 }])
  end

  def test_sentinels_connection_string_escaped
    config_obj = {
      url: 'redis://master-group-name',
      sentinels: 'redis://user:passw\,ord@127.0.0.1:26379 ,127.0.0.1:36379, ,'
    }

    conn = StorageSync.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_connector(conn)
    assert_client_config(conn, url: config_obj[:url],
                               sentinels: [{ host: '127.0.0.1', port: 26_379, password: 'passw,ord' },
                                           { host: '127.0.0.1', port: 36_379 }])
  end

  def test_sentinels_connection_array_strings
    config_obj = {
      url: 'redis://master-group-name',
      sentinels: ['redis://127.0.0.1:26379 ', ' 127.0.0.1:36379', nil]
    }

    conn = StorageSync.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_connector(conn)
    assert_client_config(conn, url: config_obj[:url],
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

    conn = StorageSync.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_connector(conn)
    assert_client_config(conn, url: config_obj[:url],
                               sentinels: config_obj[:sentinels].compact.reject(&:empty?))
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
    assert_sentinel_connector(conn)
    assert_client_config(conn, url: "redis://#{config_obj[:url]}",
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

    conn = StorageSync.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_connector(conn)
    assert_client_config(conn, url: config_obj[:url],
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

    conn = StorageSync.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_connector(conn)
    assert_client_config(conn, url: config_obj[:url],
                               sentinels: [{ host: '127.0.0.2', port: default_sentinel_port },
                                           { host: '127.0.0.1', port: default_sentinel_port },
                                           { host: '192.168.1.1', port: default_sentinel_port },
                                           { host: '127.0.0.1', port: 36379 },
                                           { host: '127.0.0.1', port: 46379 }])
  end

  def test_sentinels_array_hashes_password
    config_obj = {
        url: 'redis://master-group-name',
        sentinels: [{ host: '192.168.1.1', port: 3333, password: 'abc' },
                    { host: '192.168.1.2', port: 4444, password: '' },
                    { host: '192.168.1.3', port: 5555, password: nil }]
    }

    conn = StorageSync.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_connector(conn)
    assert_client_config(conn, url: config_obj[:url],
                         sentinels: [{ host: '192.168.1.1', port: 3333, password: 'abc' },
                                     { host: '192.168.1.2', port: 4444 },
                                     { host: '192.168.1.3', port: 5555 }])
  end

  def test_sentinels_array_strings_password
    config_obj = {
        url: 'redis://master-group-name',
        sentinels: ['redis://:abc@192.168.1.1:3333',
                    '192.168.1.2:4444',
                    'redis://192.168.1.3:5555']
    }

    conn = StorageSync.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_connector(conn)
    assert_client_config(conn, url: config_obj[:url],
                         sentinels: [{ host: '192.168.1.1', port: 3333, password: 'abc' },
                                     { host: '192.168.1.2', port: 4444 },
                                     { host: '192.168.1.3', port: 5555 }])
  end

  def test_sentinels_correct_role
    %i[master slave].each do |role|
      config_obj = {
        url: 'redis://master-group-name',
        sentinels: 'redis://127.0.0.1:26379',
        role: role
      }

      conn = StorageSync.send :new, Storage::Helpers.config_with(config_obj)
      assert_sentinel_connector(conn)
      assert_client_config(conn, url: config_obj[:url],
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

  def test_redis_no_scheme
    assert_nothing_raised do
      StorageSync.send :new, url('backend-redis:6379')
    end
  end

  def test_redis_unknown_scheme
    assert_raise ArgumentError do
      StorageSync.send :new, url('myscheme://127.0.0.1:6379')
    end
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

  private

  def assert_connection(client)
    client.flushdb
    client.set('foo', 'bar')
    assert_equal 'bar', client.get('foo')
  end

  def assert_sentinel_connector(client)
    connector = client.instance_variable_get(:@inner).instance_variable_get(:@client).instance_variable_get(:@connector)
    assert_instance_of Redis::Client::Connector::Sentinel, connector
  end

  def assert_client_config(conn, url:, **conf)
    client = conn.instance_variable_get(:@inner).instance_variable_get(:@client)
    assert_equal client.options[:url], url
    conf.each do |k, v|
      assert_equal v, client.options[k]
    end
  end

  def url(url)
    Storage::Helpers.config_with({ url: url })
  end
end
