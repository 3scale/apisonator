module ThreeScale
  module Backend
    class Storage < ::Redis
      include Configurable

      # Returns a shared instance of the storage. If there is no instance yet,
      # creates one first. If you want to always create a fresh instance, set the
      # +reset+ parameter to true.
      def self.instance(reset = false)
        @@instance = nil if reset
        @@instance ||= new(:servers     => configuration.redis.servers,
                           :db          => configuration.redis.db,
                           :backup_file => configuration.redis.backup_file)
      end

      def initialize(options)
        @client = Client.new(options)
      end

      def restore_backup
        @client.restore_backup
      end

      module Failover
        DEFAULT_SERVER = '127.0.0.1:6379'
        DEFAULT_BACKUP_FILE = '/tmp/3scale_backend/backup_storage'

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

        def initialize(options)
          @servers      = options[:servers] || []
          @server_index = 0
          @backup_file  = options[:backup_file] || DEFAULT_BACKUP_FILE

          host, port = host_and_port(@servers.first || DEFAULT_SERVER)
          super(:host => host, :port => port, :db => options[:db])
        end

        def connect
          super
        rescue Errno::ECONNREFUSED
          next_server! || raise
          connect
        end

        def process(*commands)
          logging(commands) do
            ensure_connected do
              if write_command?(commands.first) && connected_to_backup_server?
                write_to_backup(*commands)
              else
                write_to_socket(*commands)
                yield if block_given?
              end
            end
          end
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
                call(*decode_command_for_backup(line))
              end
            end

            File.delete(active_backup_file)
          end
        end

        private

        def write_to_backup(*commands)
          FileUtils.mkdir_p(File.dirname(@backup_file))

          File.open(@backup_file, 'a') do |io|
            commands.each do |command|
              io << encode_command_for_backup(command) << "\n"
            end
          end

          nil
        end

        def write_to_socket(*commands)
          commands.each do |command|
            connection.write(command)
          end
        end

        def next_server!
          return false if @server_index >= @servers.count - 1

          @server_index += 1
          @host, @port = host_and_port(current_server)
        end

        def current_server
          @servers[@server_index]
        end

        def host_and_port(server)
          host, port = server.split(':')
          port       = port.to_i

          [host, port]
        end

        def write_command?(command)
          !READ_COMMANDS.include?(command.first.to_sym)
        end

        def connected_to_backup_server?
          @server_index > 0
        end

        def encode_command_for_backup(command)
          command.map(&:to_s).map(&:escape_whitespaces).join(' ')
        end

        def decode_command_for_backup(command)
          command.split(/\s+/).map(&:unescape_whitespaces)
        end
      end

      class Client < ::Redis::Client
        include Failover
      end
    end
  end
end
