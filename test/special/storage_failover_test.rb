require File.dirname(__FILE__) + '/../test_helper'

class StorageFailoverTest < Test::Unit::TestCase
  include TestHelpers::RedisServer

  def test_with_one_server_succeeds_on_connect_when_the_server_is_up
    start_redis_server(6400)
    assert Storage.new(:servers => ['127.0.0.1:6400'])
  end
  
  def test_with_one_server_succeeds_on_commands_after_connect_when_the_server_is_up
    start_redis_server(6400)

    storage = Storage.new(:servers => ['127.0.0.1:6400'])
    storage.set('foo', 'stuff')

    assert_equal 'stuff', storage.get('foo')
  end

  def test_with_one_server_fails_on_first_command_after_the_server_goes_down
    start_redis_server(6400)      
    storage = Storage.new(:servers => ['127.0.0.1:6400'])
    storage.set('foo', 'stuff')

    assert_equal 'stuff', storage.get('foo')

    stop_redis_server(6400)

    assert_raise Errno::ECONNREFUSED do
      storage.get('foo')
    end
  end

  def test_with_one_server_succeeds_after_the_servers_goes_up_again
    start_redis_server(6400)
    storage = Storage.new(:servers => ['127.0.0.1:6400'])
    storage.set('foo', 'stuff')

    stop_redis_server(6400)

    begin
      storage.get('foo')
    rescue Errno::ECONNREFUSED
    end

    start_redis_server(6400)
    assert_equal 'stuff', storage.get('foo')
  end

  def test_with_many_servers_connects_to_the_first_server_that_is_up
    start_redis_server(6400)
    start_redis_server(6401)

    redis_send(6400, 'set my_number one')
    redis_send(6401, 'set my_number two')

    stop_redis_server(6400)

    storage = Storage.new(:servers => ['127.0.0.1:6400', '127.0.0.1:6401'])
    assert_equal 'two', storage.get('my_number')
  end

  def test_with_many_servers_tries_command_on_next_server_if_the_current_one_goes_down
    start_redis_server(6400)
    start_redis_server(6401)
    
    redis_send(6400, 'set my_number one')
    redis_send(6401, 'set my_number two')

    storage = Storage.new(:servers => ['127.0.0.1:6400', '127.0.0.1:6401'])
    assert_equal 'one', storage.get('my_number')

    stop_redis_server(6400)
    assert_equal 'two', storage.get('my_number')
  end

  def test_with_many_servers_fails_on_first_command_after_all_servers_go_down
    start_redis_server(6400)      
    start_redis_server(6401)
    
    redis_send(6400, 'set my_number one')
    redis_send(6401, 'set my_number two')

    storage = Storage.new(:servers => ['127.0.0.1:6400', '127.0.0.1:6401'])
    assert_equal 'one', storage.get('my_number')

    stop_redis_server(6400)
    assert_equal 'two', storage.get('my_number')

    stop_redis_server(6401)
    assert_raise Errno::ECONNREFUSED do
      storage.get('my_number')
    end
  end

  def test_write_commands_are_not_sent_to_backup_server
    stop_redis_server(6400)
    
    start_redis_server(6401)
    redis_send(6401, 'set foo one')
    
    storage = Storage.new(:servers => ['127.0.0.1:6400', '127.0.0.1:6401'])
    storage.set('foo', 'two')

    assert_equal 'one', redis_send(6401, 'get foo')
  end

  def test_write_commands_are_written_to_backup_file_when_connected_to_backup_server
    stop_redis_server(6400)
    start_redis_server(6401)

    File.delete('/tmp/3scale_backend/backup_storage')
    
    storage = Storage.new(:servers => ['127.0.0.1:6400', '127.0.0.1:6401'])
    storage.set('foo', '1')
    storage.set('bar', '2')
    storage.incr('foo')
    storage.incrby('bar', 42)

    assert_equal "set foo 1\nset bar 2\nincr foo\nincrby bar 42\n",
                 File.read('/tmp/3scale_backend/backup_storage')
  end
  
  def test_commands_written_to_backup_file_can_be_restored
    start_redis_server(6400)
    start_redis_server(6401)

    redis_send(6400, 'flushdb')
    redis_send(6401, 'flushdb')
    
    stop_redis_server(6400)

    FileUtils.rm_rf('/tmp/3scale_backend/backup_storage')

    servers = ['127.0.0.1:6400', '127.0.0.1:6401']
    
    storage = Storage.new(:servers => servers)
    storage.set('foo', '1')
    storage.set('bar', '2')

    start_redis_server(6400)

    storage = Storage.new(:servers => servers)
    storage.restore_backup

    assert_equal '1', storage.get('foo')
    assert_equal '2', storage.get('bar')
  end
  
  def test_commands_with_arguments_with_whitespaces_written_to_backup_file_can_be_restored
    start_redis_server(6400)
    start_redis_server(6401)

    redis_send(6400, 'flushdb')
    redis_send(6401, 'flushdb')
    
    stop_redis_server(6400)

    FileUtils.rm_rf('/tmp/3scale_backend/backup_storage')

    servers = ['127.0.0.1:6400', '127.0.0.1:6401']
    
    storage = Storage.new(:servers => servers)
    storage.rpush('queue', Yajl::Encoder.encode(:stuff => 'foo bar'))

    start_redis_server(6400)

    storage = Storage.new(:servers => servers)
    storage.restore_backup

    assert_equal 'foo bar', Yajl::Parser.parse(storage.lpop('queue'))['stuff']
  end
end
