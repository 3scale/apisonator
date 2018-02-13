require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class StorageTest < Test::Unit::TestCase
  def test_basic_operations
    @storage = Storage.instance(true)
    @storage.flushdb
    assert_nil @storage.get('foo')
    @storage.set('foo', 'bar')
    assert_equal 'bar', @storage.get('foo')
  end

  def test_redis_host_and_port
    storage = Storage.send :new, url('127.0.0.1:6379')
    assert_connection(storage)
  end

  def test_redis_url
    storage = Storage.send :new, url('redis://127.0.0.1:6379/0')
    assert_connection(storage)
  end

  def test_redis_unix
    storage = Storage.send :new, url('unix:///tmp/redis_unix.6379.sock')
    assert_connection(storage)
  end

  def test_redis_protected_url
    assert_nothing_raised do
      Storage.send :new, url('redis://user:passwd@127.0.0.1:6379/0')
    end
  end

  def test_redis_malformed_url
    assert_raise Storage::InvalidURI do
      Storage.send :new, url('a_malformed_url:1:10')
    end
  end

  def test_redis_url_without_scheme
    assert_nothing_raised do
      Storage.send :new, url('foo')
    end
  end

  def test_redis_no_scheme
    assert_nothing_raised do
      Storage.send :new, url('backend-redis:6379')
    end
  end

  def test_redis_unknown_scheme
    assert_raise ArgumentError do
      Storage.send :new, url('myscheme://127.0.0.1:6379')
    end
  end

  def test_sentinels_connection
    config_obj = {
      url: 'redis://127.0.0.1:6379/0',
      sentinels: 'redis://127.0.0.1:26379,127.0.0.1:36379'
    }
    conn = Storage.send :orig_new, Storage::Helpers.config_with(config_obj)
    connector = conn.client.instance_variable_get(:@connector)
    assert_instance_of Redis::Client::Connector::Sentinel, connector
  end

  def test_sentinels_malformed_url
    config_obj = {
      url: 'redis://127.0.0.1:6379/0',
      sentinels: 'redis://127.0.0.1:26379,a_malformed_url:1:10'
    }
    assert_raise Storage::InvalidURI do
      Storage.send :new, Storage::Helpers.config_with(config_obj)
    end
  end

  private

  def assert_connection(client)
    client.flushdb
    client.set('foo', 'bar')
    assert_equal 'bar', client.get('foo')
  end

  def url(url)
    Storage::Helpers.config_with(url: url)
  end
end
