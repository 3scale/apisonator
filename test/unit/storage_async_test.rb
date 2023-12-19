require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

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

  def test_redis_unix
    storage = StorageAsync::Client.send :new, url('unix:///tmp/redis_unix.6379.sock')
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


  def url(url)
    Storage::Helpers.config_with({ url: url })
  end
end
