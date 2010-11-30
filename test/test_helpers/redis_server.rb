module TestHelpers
  module RedisServer
    def setup
      @open_ports = []
    end

    def teardown
      stop_all_redis_servers
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
save 1 1
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
end
