require File.dirname(__FILE__) + '/../test_helper'

class StorageFailoverTest < Test::Unit::TestCase
  include TestHelpers::EventMachine

  def setup
    @open_ports = []
  end

  def teardown
    stop_all_redis_servers
  end

  def test_with_one_server_succeeds_on_connect_when_the_server_is_up
    start_redis_server(6400)

    assert Storage.connect(:servers => ['127.0.0.1:6400'])
  end
  
  def test_with_one_server_succeeds_on_commands_after_connect_when_the_server_is_up
    start_redis_server(6400)
    
    storage = Storage.connect(:servers => ['127.0.0.1:6400'])
    storage.set('foo', 'stuff')

    assert_equal 'stuff', storage.get('foo')
  end

  def test_with_one_server_fails_on_connect_when_the_server_is_down
    stop_redis_server(6400)

    assert_raise Storage::ConnectionError do
      Storage.connect(:servers => ['127.0.0.1:6400'])
    end
  end

  def test_with_one_server_fails_on_first_command_after_the_server_goes_down
    start_redis_server(6400)      
    storage = Storage.connect(:servers => ['127.0.0.1:6400'])
    storage.set('foo', 'stuff')

    assert_equal 'stuff', storage.get('foo')

    stop_redis_server(6400)

    assert_raise Storage::ConnectionError do
      storage.get('foo')
    end
  end

  def test_with_one_server_succeeds_after_the_servers_goes_up_again
    start_redis_server(6400)
    storage = Storage.connect(:servers => ['127.0.0.1:6400'])
    storage.set('foo', 'stuff')

    stop_redis_server(6400)

    begin
      storage.get('foo')
    rescue Storage::ConnectionError
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

    storage = Storage.connect(:servers => ['127.0.0.1:6400', '127.0.0.1:6401'])
    assert_equal 'two', storage.get('my_number')
  end

  def test_with_many_servers_tries_command_on_next_server_if_the_current_one_goes_down
    start_redis_server(6400)
    start_redis_server(6401)
    
    redis_send(6400, 'set my_number one')
    redis_send(6401, 'set my_number two')

    storage = Storage.connect(:servers => ['127.0.0.1:6400', '127.0.0.1:6401'])
    assert_equal 'one', storage.get('my_number')

    stop_redis_server(6400)
    assert_equal 'two', storage.get('my_number')
  end

  def test_with_many_servers_fails_on_connect_when_all_servers_are_down
    stop_redis_server(6400)
    stop_redis_server(6401)

    assert_raise Storage::ConnectionError do
      storage = Storage.connect(:servers => ['127.0.0.1:6400', '127.0.0.1:6401'])
    end
  end
  
  def test_with_many_servers_fails_on_first_command_after_all_servers_go_down
    start_redis_server(6400)      
    start_redis_server(6401)
    
    redis_send(6400, 'set my_number one')
    redis_send(6401, 'set my_number two')

    storage = Storage.connect(:servers => ['127.0.0.1:6400', '127.0.0.1:6401'])
    assert_equal 'one', storage.get('my_number')

    stop_redis_server(6400)
    assert_equal 'two', storage.get('my_number')

    stop_redis_server(6401)
    assert_raise Storage::ConnectionError do
      storage.get('my_number')
    end
  end

  def test_write_commands_are_not_send_to_backup_server
    stop_redis_server(6400)
    
    start_redis_server(6401)
    redis_send(6401, 'set foo one')
    
    storage = Storage.connect(:servers => ['127.0.0.1:6400', '127.0.0.1:6401'])
    storage.set('foo', 'two')

    assert_equal 'one', redis_send(6401, 'get foo')
  end

  def test_write_commands_are_written_to_backup_file_when_connected_to_backup_server
    stop_redis_server(6400)
    start_redis_server(6401)

    File.delete('/tmp/3scale_backend/backup_storage')
    
    storage = Storage.connect(:servers => ['127.0.0.1:6400', '127.0.0.1:6401'])
    storage.set('foo', 'one')
    storage.set('bar', 'two')

    assert_equal "set foo one\nset bar two\n",
                 File.read('/tmp/3scale_backend/backup_storage')
  end

  private

  def redis_send(port, command)
    `redis-cli -p #{port} #{command}`
  end

  def start_redis_server(port)
    path = write_redis_server_configuration(port)

    if silent_system("redis-server #{path}")
      # Make sure the server is ready before continuing.
      sleep(0.01) until silent_system("redis-cli -p #{port} info")

      @open_ports << port
    end
  end

  def stop_redis_server(port)
    silent_system("redis-cli -p #{port} shutdown")
    @open_ports.delete(port)
  end

  def stop_all_redis_servers
    @open_ports.dup.each do |port|
      stop_redis_server(port)
    end
  end

  def write_redis_server_configuration(port)
    content = <<END
daemonize yes
pidfile /tmp/test-redis-#{port}.pid
port #{port}
databases 1
dbfilename test-dump-#{port}.rdb
dir /tmp/
END

    path = "/tmp/test-redis-#{port}.conf"
    File.open(path, 'w') { |io| io.write(content) }

    path
  end

  def silent_system(command)
    silence_output { system(command) }
  end

  def silence_output
    original_stdout = STDOUT.dup
    original_stderr = STDERR.dup

    STDOUT.reopen('/dev/null')
    STDOUT.sync = true
    
    STDERR.reopen('/dev/null')
    STDERR.sync = true

    yield
  ensure
    STDOUT.reopen(original_stdout)
    STDERR.reopen(original_stderr)
  end
end
