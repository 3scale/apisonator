module ThreeScale
  module Backend
    class Storage < ::Redis
      include Configurable

      DEFAULT_SERVER = '127.0.0.1:6379'
      DEFAULT_BACKUP_FILE = '/tmp/3scale_backend/backup_storage'


      # Returns a shared instance of the storage. If there is no instance yet,
      # creates one first. If you want to always create a fresh instance, set the
      # +reset+ parameter to true.
      def self.instance(reset = false)

        @@instance = nil if reset
        @@instance ||= new(:servers     => configuration.redis.servers,
                           :db          => configuration.redis.db,
                           :backup_file => configuration.redis.backup_file)
        @@instance
      end

      def host_and_port(server)
        host, port = server.split(':')
        port       = port.to_i

        [host, port]
      end

      def initialize(options)

        @servers      = options[:servers] || []
        @server_index = 0
        @backup_file  = options[:backup_file] || DEFAULT_BACKUP_FILE

        host, port = host_and_port(@servers.first || DEFAULT_SERVER)
        super(:host => host, :port => port, :db => options[:db])

        @client = Redis::Client.new(options)
      end

    end
  end
end
