require 'net/http'
require 'timeout'

module ListenerServerHelper
  def start_listener_server(options = {})
    port = options.fetch(:port)
    server = options.fetch(:server)
    bind_address = options[:bind]
    environment_vars = options[:environment] || {}

    bind_option = bind_address ? "--bind #{bind_address}" : ""
    env_str = environment_vars.map { |env, val| "#{env}=#{val}" }.join(' ')
    env_prefix = env_str.empty? ? "" : "#{env_str} "

    # Send logs to /dev/null to avoid cluttering the output
    start_cmd = "#{env_prefix}bundle exec bin/3scale_backend -s #{server} start #{bind_option} -p #{port} 2> /dev/null &"
    start_ok = system(start_cmd)
    raise "Failed to start Listener on #{bind_address || 'default'}:#{port}" unless start_ok

    # Wait for the server to be ready
    host = bind_address || "127.0.0.1"
    wait_for_server_ready(host, port, 20)
  end

  def stop_listener_server(port, server, bind_address = nil)
    if server == :puma
      bind_option = bind_address ? "--bind #{bind_address}" : ""
      system("bundle exec bin/3scale_backend stop #{bind_option} -p #{port}")
      sleep(2) # Give it some time to stop
    else # stop not implemented in Falcon
      system("pkill -u #{Process.euid} -f \"ruby .*falcon\"")
      sleep(2) # Give it some time to stop

      # TODO: investigate why occasionally Falcon does not kill its children
      # processes ("Falcon Server").
      if system("pkill -u #{Process.euid} -f \"Falcon Server\"")
        sleep(2)
        system("pkill --signal SIGKILL -u #{Process.euid} -f \"Falcon Server\"")
      end
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
end
