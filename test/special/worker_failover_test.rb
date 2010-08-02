require File.dirname(__FILE__) + '/../test_helper'

class StorageFailoverTest < Test::Unit::TestCase
  include TestHelpers::RedisServer
  include Configurable

  def setup
    super
    @original_servers = configuration.redis.servers
  end

  def teardown
    super
    configuration.redis.servers = @original_servers
  end

  def test_worker_fails_when_main_server_is_down
    stop_redis_server(6400)
    start_redis_server(6401)

    configuration.redis.servers = ['127.0.0.1:6400', '127.0.0.1:6401']

    assert_raises Errno::ECONNREFUSED do
      Worker.work(:one_off => true)
    end
  end

  def test_worker_does_not_write_anything_to_the_backup_storage_if_main_server_is_down
    stop_redis_server(6400)
    start_redis_server(6401)
    
    FileUtils.rm_rf(Storage::Failover::DEFAULT_BACKUP_FILE)
    FileUtils.touch(Storage::Failover::DEFAULT_BACKUP_FILE)

    configuration.redis.servers = ['127.0.0.1:6400', '127.0.0.1:6401']

    begin
      Worker.work(:one_off => true)
    rescue Errno::ECONNREFUSED
    end
    
    assert_equal '', File.read(Storage::Failover::DEFAULT_BACKUP_FILE)
  end
end
