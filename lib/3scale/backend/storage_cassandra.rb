module ThreeScale
  module Backend
    class StorageCassandra < ::CassandraCQL::Database
      include Configurable
      include Backend::Aggregator::StatsBatcher

      # Returns a shared instance of the storage. If there is no instance yet,
      # creates one first. If you want to always create a fresh instance, set the
      # +reset+ parameter to true.
      def self.instance(reset = false)
       
        @@instance = nil if reset
        @@instance ||= new(:keyspace => configuration.cassandra.keyspace,
                           :servers  => configuration.cassandra.servers)
        @@instance      
      end
      
      def self.reset_to_nil!
        @@instance = nil
      end
      
      def clear_keyspace!
        schema.column_family_names.each do |cf|
          execute("truncate #{cf}")
        end
      end
      
      def add(column_family, row_key, value, col_key)
        execute(add2cql(column_family, row_key, value, col_key))
      end
      
      def get(column_family, row_key, col_key)
        r = execute(get2cql(column_family, row_key, col_key))
        r.fetch do |row|
          return row.to_hash[col_key]
        end 
        return nil
      end
      
      
      
      module Failover
        
        DEFAULT_SERVER = '127.0.0.1:9160'
        DEFAULT_KEYSPACE = 'backend_test'
        THRIFT_OPTIONS = {:retries => 3, :timeout => 3}
        
        ## for no reason cassandra-cql does not allow keyspaces that start with a number (3scale)

        def initialize(options)
          @init_servers = options[:servers] || Array(DEFAULT_SERVER)
          @init_keyspace = options[:keyspace] || DEFAULT_KEYSPACE
          @init_server_index = 0
                    
          connected = false
          while (not connected) and next_server?
            
            begin
              host_and_port = current_server
              super(host_and_port,{:keyspace => @init_keyspace}, THRIFT_OPTIONS)
              connected = true
            rescue Exception 
              if next_server!
                host_and_port = current_server
              else
                raise Errno::ECONNREFUSED, "Connection refused to all cassandra nodes: #{@init_servers}"
              end
            end
          end
            
        end

        private

        def next_server!
          return false if @init_server_index >= @init_servers.count - 1
          @init_server_index += 1
        end
        
        def next_server?
          return true if @init_server_index < @init_servers.count
          return false
        end

        def current_server
          @init_servers[@init_server_index]
        end

      end
          
      include Failover
          
    end
  end
end
