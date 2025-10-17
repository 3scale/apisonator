require 'net/http'
require 'socket'
require 'tempfile'

module ListenerServerHelper

  def find_free_port
    socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
    socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)
    socket.bind(Socket.sockaddr_in(0, '127.0.0.1'))
    port = socket.local_address.ip_port
    socket.close
    port
  end

  def start_listener_server(options = {})
    port = options.fetch(:port)
    server = options.fetch(:server)
    bind_address = options[:bind]
    environment_vars = options[:environment] || {}

    bind_option = bind_address ? "--bind #{bind_address}" : ""
    env_str = environment_vars.map { |env, val| "#{env}=#{val}" }.join(' ')
    env_prefix = env_str.empty? ? "" : "#{env_str} "

    # Create tempfile for server logs
    log_file = Tempfile.new(["listener_#{server}_#{port}", ".log"])

    begin
      # Capture both stdout and stderr to log file
      start_cmd = "#{env_prefix}bundle exec bin/3scale_backend -s #{server} start #{bind_option} -p #{port} > #{log_file.path} 2>&1 &"
      start_ok = system(start_cmd)

      unless start_ok
        show_server_logs(log_file.path, "Failed to execute start command for #{server} on #{bind_address || 'default'}:#{port}")
        raise "Failed to start Listener on #{bind_address || 'default'}:#{port}"
      end

      # Wait for the server to be ready
      host = bind_address || "127.0.0.1"
      wait_for_server_ready(host, port, 20)
    rescue => e
      show_server_logs(log_file.path, "Server failed to become ready: #{server} on #{bind_address || 'default'}:#{port}")
      raise e
    ensure
      log_file.close # Close handle but keep file
      log_file.unlink # Always clean up
    end
  end

  def stop_listener_server(port, server, bind_address = nil)
    if server == :puma
      bind_option = bind_address ? "--bind #{bind_address}" : ""
      system("bundle exec bin/3scale_backend stop #{bind_option} -p #{port}")
      sleep(2) # Give it some time to stop

      # Clean up Puma control socket
      puma_socket = '3scale_backend.sock'
      File.unlink(puma_socket) if File.exist?(puma_socket)
    else # stop not implemented in Falcon
      system("pkill -u #{Process.euid} -f \"ruby .*falcon\"")
      sleep(2) # Give it some time to stop

      # TODO: investigate why occasionally Falcon does not kill its children
      # processes ("Falcon Server").
      if system("pkill -u #{Process.euid} -f \"Falcon Server\"")
        sleep(2)
        system("pkill --signal SIGKILL -u #{Process.euid} -f \"Falcon Server\"")
      end

      # Clean up Falcon IPC socket
      ipc_path = '/tmp/apisonator_supervisor.ipc'
      File.unlink(ipc_path) if File.exist?(ipc_path)
    end
  end

  def wait_for_server_ready(host, port, max_attempts, endpoint = '/status')
    attempt = 1
    while attempt <= max_attempts
      begin
        make_http_request(host, port, endpoint)
        return true
      rescue SystemCallError
        sleep 1
        attempt += 1
      end
    end
    raise "Server failed to start after #{max_attempts} attempts"
  end

  def make_http_request(host, port, path, timeout = 30)
    # Remove brackets from IPv6 addresses for Net::HTTP
    clean_host = host.gsub(/^\[|\]$/, '')

    http = Net::HTTP.new(clean_host, port)
    http.open_timeout = timeout
    http.read_timeout = timeout
    http.get(path)
  end

  private

  def show_server_logs(log_path, context)
    return unless File.exist?(log_path)

    logs = File.read(log_path)
    puts "\n#{context}"
    puts "=" * 60
    puts "Server logs:"
    puts logs
    puts "=" * 60
  end

end
