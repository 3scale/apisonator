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

  # can't really test UNIX path or protected Redis instances unless we configure
  # and launch the Redis instance accordingly... so much for a unit test.
  def test_redis_unix
    assert_nothing_raised do
      Storage.send :new, url('unix:///tmp/redis.sock')
    end
  end

  def test_redis_protected_url
    assert_nothing_raised do
      Storage.send :new, url('redis://user:passwd@127.0.0.1:6379/0')
    end
  end

  def test_redis_malformed_url
    assert_raise do
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
