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

      DEFAULT_BACKUP_FILE = '/tmp/3scale_backend/backup_storage'

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
        reconnect(args.first.to_sym != :select) if @disconnected

        fiber = Fiber.current
        push_calling_fiber(fiber)
          
        callback do
          raw_call_command(args) do |response|
            fiber.resume(:success, response)
          end
        end

        status, response = Fiber.yield
        pop_calling_fiber

        case status
        when :success
          response
        when :retry_on_next_server
          next_server!
          call_command(args, &block)
        when :retry
          call_command(args, &block)
        else
          raise "Unknown response status: #{status.inspect}"
        end
      end

      def initialize(options)
        @servers        = options[:servers]
        @server_index   = 0
        
        @db             = options[:db] || 0
        @backup_file    = options[:backup_file] || DEFAULT_BACKUP_FILE

        @disconnected   = false
        @calling_fibers = []
      end

      def unbind
        @disconnected = true

        fail unless @calling_fibers.empty?
        retry_pending_commands
      end

      def reconnect(reselect = true)
        @disconnected = false

        # I need to do this so the deferred callbacks are called only after
        # the reconnection is completed, not immediately.
        set_deferred_status(:unknown)

        host, port = host_and_port(current_server)        
        super(host, port)
        select(@db) if reselect
      end

      def restore_backup
        if File.readable?(@backup_file)
          # To restore the backup, I first copy the backup file and delete the original.
          # This is for the case the server goes down during the backup restore, so the
          # failed commands are backed up again to a fresh file.

          active_backup_file = @backup_file + '.active'

          FileUtils.cp(@backup_file, active_backup_file)
          File.delete(@backup_file)

          File.open(active_backup_file, 'r') do |io|
            io.each_line do |line|
              call_command(decode_command_for_backup(line))
            end
          end

          File.delete(active_backup_file)
        end
      end

      private

      def retry_pending_commands
        resume_fibers(@calling_fibers[0..0],  :retry_on_next_server)
        resume_fibers(@calling_fibers[1..-1], :retry)
      end

      def resume_fibers(fibers, status)
        if fibers && fibers.size > 0
          EM.next_tick { fibers[0].resume(status) }
          resume_fibers(fibers[1..-1], status)
        end
      end

      def push_calling_fiber(fiber)
        @calling_fibers.push(fiber)
      end

      def pop_calling_fiber
        @calling_fibers.shift
      end

      def next_server!
        raise ConnectionError if @server_index >= @servers.count - 1

        @server_index += 1
        @disconnected = true
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
        if write_command?(args.first) && connected_to_backup_server?
          FileUtils.mkdir_p(File.dirname(@backup_file))

          File.open(@backup_file, 'a') do |io|
            io << encode_command_for_backup(args) << "\n"
          end

          EM.next_tick { block.call(nil) }
        else
          super
        end
      end

      def encode_command_for_backup(command)
        # TODO: would be good to escape spaces and newlines in each argument,
        # but the normal (non-backup) processig doesn't do it neither, so let's
        # not bother now.
        command.join(' ')
      end

      def decode_command_for_backup(command)
        command.split(/\s+/)
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
