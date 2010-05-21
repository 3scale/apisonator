module ThreeScale
  module Backend
    module Storage
      include Configurable
      include EM::Protocols::Redis
      
      class ConnectionError < RuntimeError
        def initialize(message = 'redis connection lost')
          super
        end
      end

      READ_COMMANDS = [
        :exists,
        :type,
        :keys,
        :randomkey,
        :dbsize,
        :ttl,

        :get,
        :mget,

        :llen,
        :lrange,
        :lindex,

        :scard,
        :sismember,
        :sinter,
        :sunion,
        :sdiff,
        :smembers,
        :srandmember,

        :zrank,
        :zrevrank,
        :zrange,
        :zrevrange,
        :zrangebyscore,
        :zcard,
        :zscore,
        :zunion,
        :zinter,

        :hget,
        :hexists,
        :hlen,
        :hkeys,
        :hvals,
        :hgetall,

        :sort,

        :lastsave,

        :info,

        # This is not a typical read command, but it's definitelly not write.
        :select        
      ].to_set

      # Returns a shared instance of the storage. If there is no instance yet,
      # creates one first. If you want to always create a fresh instance, set the 
      # +reset+ parameter to true.
      def self.instance(reset = false)
        @@instance = nil if reset
        @@instance ||= connect(:servers => configuration.redis.servers,
                               :db      => configuration.redis.db)
      end

      def self.connect(options)
        host, port = host_and_port((options[:servers] || []).first)

        connection = EM.connect(host, port, self, options)
        connection.select(options[:db] || 0)
        connection
      end

      def call_command(args, &block)
        reconnect if @disconnected

        fiber = Fiber.current
        push_calling_fiber(fiber)
          
        callback do
          raw_call_command(args) do |response|
            fiber.resume(true, response)
          end
        end

        success, payload = Fiber.yield
        pop_calling_fiber

        success ? payload : try_to_call_command_on_next_server(args, &block)
      end

      def initialize(options)
        @servers        = options[:servers]
        @server_index   = 0
        
        @db             = options[:db] || 0
        @backup_path    = options[:backup_path] || '/tmp/3scale_backend/backup_storage'

        @disconnected   = false
        @calling_fibers = []
      end

      def unbind
        @disconnected = true
        resume_calling_fibers
      end

      def reconnect
        @disconnected = false

        # I need to do this so the deferred callbacks are called only after
        # the reconnection is completed, not immediately.
        set_deferred_status(:unknown)

        host, port = host_and_port(current_server)        
        super(host, port)
        select(@db)
      end

      private
      
      def try_to_call_command_on_next_server(args, &block)
        if has_more_servers?
          next_server!
          call_command(args, &block)
        else
          raise ConnectionError
        end
      end

      def next_server!
        @disconnected = true
        @server_index += 1
      end

      def has_more_servers?
        (@server_index + 1) < @servers.size
      end

      def current_server
        @servers[@server_index]
      end

      def connected_to_backup_server?
        @server_index > 0
      end
      
      def write_command?(command)
        !READ_COMMANDS.include?(command.to_sym)
      end

      def raw_call_command(args, &block)
        data = compile_command(args)

        if write_command?(args.first) && connected_to_backup_server?
          FileUtils.mkdir_p(File.dirname(@backup_path))
          File.open(@backup_path, 'a') { |io| io << data }

          EM.next_tick { block.call(nil) }
        else
          @redis_callbacks << [REPLY_PROCESSOR[args[0]], block]
          send_data(data)
        end
      end

      def compile_command(argv)
        # This code is copied straight over from em-redis gem.

        argv = argv.dup

        if MULTI_BULK_COMMANDS[argv.flatten[0].to_s]
          argvp   = argv.flatten
          values  = argvp.pop.to_a.flatten
          argvp   = values.unshift(argvp[0])
          command = ["*#{argvp.size}"]
          argvp.each do |v|
            v = v.to_s
            command << "$#{get_size(v)}"
            command << v
          end
          command = command.map {|cmd| "#{cmd}\r\n"}.join
        else
          command = ""
          bulk = nil
          argv[0] = argv[0].to_s.downcase
          argv[0] = ALIASES[argv[0]] if ALIASES[argv[0]]
          raise "#{argv[0]} command is disabled" if DISABLED_COMMANDS[argv[0]]
          if BULK_COMMANDS[argv[0]] and argv.length > 1
            bulk = argv[-1].to_s
            argv[-1] = get_size(bulk)
          end
          command << "#{argv.join(' ')}\r\n"
          command << "#{bulk}\r\n" if bulk
        end

        command
      end

      def push_calling_fiber(fiber)
        @calling_fibers.unshift(fiber)
      end

      def pop_calling_fiber
        @calling_fibers.pop
      end

      def resume_calling_fibers
        if fiber = pop_calling_fiber
          fail
          EM.next_tick { fiber.resume(false) }

          resume_calling_fibers
        end
      end

      module ConfigurationHelpers
        DEFAULT_SERVER = '127.0.0.1:6379'

        def host_and_port(server)
          host, port = (server || DEFAULT_SERVER).split(':')
          port       = port.to_i

          [host, port]
        end
      end

      include ConfigurationHelpers
      extend  ConfigurationHelpers
    end
  end
end
