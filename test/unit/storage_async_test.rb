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
    config_obj = url('127.0.0.1:6379')
    storage = StorageAsync::Client.send :new, config_obj
    assert_client_config(config_obj, storage)
  end

  def test_redis_url
    config_obj = url('redis://127.0.0.1:6379/0')
    storage = StorageAsync::Client.send :new, config_obj
    assert_client_config(config_obj, storage)
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
    assert_sentinel_config({ url: config_obj[:url],
                           sentinels: [{ host: '127.0.0.1', port: 26_379 },
                                       { host: '127.0.0.1', port: 36_379 }] },
                           conn)
  end

  def test_sentinels_connection_array_strings
    config_obj = {
      url: 'redis://master-group-name',
      sentinels: ['redis://127.0.0.1:26379 ', ' 127.0.0.1:36379', nil]
    }

    conn = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_config({ url: config_obj[:url],
                           sentinels: [{ host: '127.0.0.1', port: 26_379 },
                                       { host: '127.0.0.1', port: 36_379 }] },
                           conn)
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
    assert_sentinel_config({ url: config_obj[:url],
                           sentinels: config_obj[:sentinels].compact.reject(&:empty?) },
                           conn)
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
      url: 'redis://master-group-name', # url of the sentinel master name conf
      sentinels: 'redis://127.0.0.1:26379'
    }

    conn = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_config({ url: config_obj[:url],
                           sentinels: [{ host: '127.0.0.1', port: 26_379 }] },
                           conn)
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
    assert_sentinel_config({ url: config_obj[:url],
                           sentinels: [{ host: '127.0.0.1', port: default_sentinel_port },
                                       { host: '192.168.1.1', port: default_sentinel_port },
                                       { host: '192.168.1.2', port: default_sentinel_port },
                                       { host: '127.0.0.1', port: 36379 }] },
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

    conn = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_config({ url: config_obj[:url],
                           sentinels: [{ host: '127.0.0.2', port: default_sentinel_port },
                                       { host: '127.0.0.1', port: default_sentinel_port },
                                       { host: '192.168.1.1', port: default_sentinel_port },
                                       { host: '127.0.0.1', port: 36379 },
                                       { host: '127.0.0.1', port: 46379 }] },
                           conn)
  end

  def test_sentinels_correct_role
    %i[master slave].each do |role|
      config_obj = {
        url: 'redis://master-group-name',
        sentinels: 'redis://127.0.0.1:26379',
        role: role
      }

      conn = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
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
    [nil, '', ' ', [], [nil], [''], [' '], [{}]].each do |sentinels_val|
      config_obj = {
        url: 'redis://master-group-name',
        sentinels: sentinels_val
      }
      redis_cfg = Storage::Helpers.config_with(config_obj)
      refute redis_cfg.key?(:sentinels)
    end
  end

  def test_redis_no_scheme
    storage = StorageAsync::Client.send :new, url('backend-redis')
    assert_client_config({ url: URI('redis://backend-redis:6379') }, storage)
  end

  private

  def assert_client_config(conf, conn)
    client = conn.instance_variable_get(:@redis_async)

    url = URI(conf[:url])
    host, port = client.endpoint.address
    assert_equal url.host, host
    assert_equal url.port, port
  end

  def assert_sentinel_config(conf, conn)
    client = conn.instance_variable_get(:@redis_async)
    uri = URI(conf[:url] || '')
    name = uri.host
    role = conf[:role] || :master
    password = client.instance_variable_get(:@protocol).instance_variable_get(:@password)

    assert_instance_of Async::Redis::SentinelsClient, client

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
