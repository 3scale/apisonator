require 'tempfile'
require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require '3scale/backend/storage_async'

class StorageAsyncTest < Test::Unit::TestCase
  include TestHelpers::Certificates

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
    config_obj = url('redis://127.0.0.1:6379')
    storage = StorageAsync::Client.send :new, config_obj
    assert_client_config(config_obj, storage)
  end

  def test_redis_unix
    config_obj = url('unix:///tmp/redis_unix.6379.sock')
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

  def test_redis_no_scheme
    storage = StorageAsync::Client.send :new, url('backend-redis')
    assert_client_config({ url: URI('redis://backend-redis:6379') }, storage)
  end

  def test_redis_db_nil
    config_obj = url('redis://backend-redis:6379')
    storage = StorageAsync::Client.send :new, config_obj
    assert_client_config({ **config_obj, db: nil } , storage)
  end

  def test_redis_db_int
    config_obj = url('redis://backend-redis:6379/6')
    storage = StorageAsync::Client.send :new, config_obj
    assert_client_config({ **config_obj, db: '6' }, storage)
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
    [nil, '', ' ', [], [nil], [''], [' ']].each do |sentinels_val|
      config_obj = {
        url: 'redis://master-group-name',
        sentinels: sentinels_val
      }
      redis_cfg = Storage::Helpers.config_with(config_obj)
      refute redis_cfg.key?(:sentinels)
    end
  end

  def test_sentinels_acl
    config_obj = {
      url: 'redis://master-group-name',
      sentinels: 'redis://127.0.0.1:26379, redis://127.0.0.1:36379, redis://127.0.0.1:46379',
      username: 'apisonator-test',
      password: 'p4ssW0rd',
      sentinel_username: 'sentinel-test',
      sentinel_password: 'p4ssW0rd#'
    }

    conn = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_config({ **config_obj,
                             sentinels: [{ host: '127.0.0.1', port: 26_379 },
                                         { host: '127.0.0.1', port: 36_379 },
                                         { host: '127.0.0.1', port: 46_379 }]},
                           conn)
  end

  def test_sentinels_acl_tls
    ca_file, cert, key = create_certs(:rsa).values_at(:ca_file, :cert, :key)

    config_obj = {
      url: 'rediss://master-group-name',
      sentinels: 'rediss://127.0.0.1:26379, rediss://127.0.0.1:36379, rediss://127.0.0.1:46379',
      username: 'apisonator-test',
      password: 'p4ssW0rd',
      sentinel_username: 'sentinel-test',
      sentinel_password: 'p4ssW0rd#',
      ssl_params: {
        ca_file: ca_file.path,
        cert: cert.path,
        key: key.path
      }
    }

    conn = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
    assert_sentinel_config({ **config_obj,
                             sentinels: [{ host: '127.0.0.1', port: 26_379 },
                                         { host: '127.0.0.1', port: 36_379 },
                                         { host: '127.0.0.1', port: 46_379 }]},
                           conn, :rsa)
  ensure
    [ca_file, cert, key].each(&:unlink)
  end

  def test_tls_no_client_certificate
    config_obj = {
      url: 'rediss://localhost:46379',
      ssl_params: {
        ca_file: create_ca(:rsa).path
      }
    }
    storage = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
    assert_client_config(config_obj, storage)
  end

  [:rsa, :dsa, :ec].each do |alg|
    define_method "test_tls_client_cert_#{alg}" do
      ca_file, cert, key = create_certs(alg).values_at(:ca_file, :cert, :key)

      config_obj = {
        url: 'rediss://localhost:46379',
        ssl_params: {
          ca_file: ca_file.path,
          cert: cert.path,
          key: key.path
        }
      }
      storage = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
      assert_client_config(config_obj, storage, alg)
    ensure
      [ca_file, cert, key].each(&:unlink)
    end
  end

  def test_acl
    config_obj = {
      url: 'redis://localhost:6379',
      username: 'apisonator-test',
      password: 'p4ssW0rd'
    }
    storage = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
    assert_client_config(config_obj, storage)
  end

  def test_acl_tls
    ca_file, cert, key = create_certs(:rsa).values_at(:ca_file, :cert, :key)

    config_obj = {
      url: 'rediss://localhost:46379',
      ssl_params: {
        ca_file: ca_file.path,
        cert: cert.path,
        key: key.path
      },
      username: 'apisonator-test',
      password: 'p4ssW0rd'
    }
    storage = StorageAsync::Client.send :new, Storage::Helpers.config_with(config_obj)
    assert_client_config(config_obj, storage)
  ensure
    [ca_file, cert, key].each(&:unlink)
  end

  private

  def create_ca(alg)
    Tempfile.new('ca-root-cert.pem').tap do |ca_cert_file|
      ca_cert_file.write(create_cert(create_key(alg)).to_pem)
      ca_cert_file.flush
      ca_cert_file.close
    end
  end

  def create_certs(alg)
    ca_cert_file = create_ca(alg)

    key = create_key alg
    key_file = Tempfile.new("redis-#{alg}.pem")
    key_file.write(key.to_pem)
    key_file.flush
    key_file.close

    cert_file = Tempfile.new("redis-#{alg}.crt")
    cert_file.write(create_cert(key).to_pem)
    cert_file.flush
    cert_file.close

    { ca_file: ca_cert_file, cert: cert_file, key: key_file }
  end

  def assert_client_config(conf, conn, test_cert_type = nil)
    client = conn.instance_variable_get(:@inner).instance_variable_get(:@redis_async)

    if conf[:url].to_s.strip.empty?
      path = conf[:path]
      assert_equal path, client.endpoint.path
    else
      url = URI(conf[:url])
      host, port = client.endpoint.address
      assert_equal url.host, host
      assert_equal url.port, port
      db = client.protocol.instance_variable_get(:@db)
      assert_equal conf[:db], db
    end

    assert_acl_credentials(conf, client)
    assert_tls_certs(conf, client, test_cert_type)
  end

  def assert_sentinel_config(conf, conn, test_cert_type = nil)
    client = conn.instance_variable_get(:@inner).instance_variable_get(:@redis_async)
    uri = URI(conf[:url] || '')
    name = uri.host
    role = conf[:role] || :master

    assert_instance_of ThreeScale::Backend::AsyncRedis::SentinelsClientACLTLS, client

    assert_acl_credentials(conf, client)
    assert_tls_certs(conf, client, test_cert_type)

    assert_equal name, client.instance_variable_get(:@master_name)
    assert_equal role, client.instance_variable_get(:@role)

    assert_equal conf[:sentinels].size, client.instance_variable_get(:@sentinel_endpoints).size
    client.instance_variable_get(:@sentinel_endpoints).each_with_index do |endpoint, i|
      host, port = endpoint.address
      assert_equal conf[:sentinels][i][:host], host
      assert_equal conf[:sentinels][i][:port], port
    end unless conf[:sentinels].empty?
  end

  def assert_acl_credentials(conf, client)
    if conf[:username].to_s.strip.empty? && conf[:password].to_s.strip.empty?
      assert_nil conf[:username]
      assert_nil conf[:password]
    else
      assert_instance_of ThreeScale::Backend::AsyncRedis::Protocol::ExtendedRESP2, client.protocol
      username, password = client.protocol.instance_variable_get(:@credentials)
      assert_equal conf[:username], username
      assert_equal conf[:password], password
    end

    if conf[:sentinel_username].to_s.strip.empty? && conf[:sentinel_password].to_s.strip.empty?
      assert_nil conf[:sentinel_username]
      assert_nil conf[:sentinel_password]
    else
      sentinel_username, sentinel_password = client.instance_variable_get(:@sentinel_credentials)
      assert_equal conf[:sentinel_username], sentinel_username
      assert_equal conf[:sentinel_password], sentinel_password
    end
  end

  def assert_tls_certs(conf, client, test_cert_type)
    unless conf[:ssl_params].to_s.strip.empty?
      endpoint = client.endpoint || client.instance_variable_get(:@sentinel_endpoints).first
      assert_instance_of Async::IO::SSLEndpoint, endpoint
      assert_equal conf[:ssl_params][:ca_file], endpoint.options[:ssl_context].send(:ca_file)
      assert_instance_of(OpenSSL::X509::Certificate, endpoint.options[:ssl_context].cert) unless conf[:ssl_params][:cert].to_s.strip.empty?

      unless test_cert_type.to_s.strip.empty?
        expected_classes = {
          rsa: OpenSSL::PKey::RSA,
          dsa: OpenSSL::PKey::DSA,
          ec: OpenSSL::PKey::EC,
        }
        assert_instance_of(expected_classes[test_cert_type], endpoint.options[:ssl_context].key) unless conf[:ssl_params][:key].to_s.strip.empty?
      end
    end
  end

  def url(url)
    Storage::Helpers.config_with({ url: url })
  end
end
