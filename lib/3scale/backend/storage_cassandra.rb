module ThreeScale
  module Backend
    class StorageCassandra < ::CassandraCQL::Database
      include Configurable
      include Backend::Aggregator::StatsBatcher

      DEFAULT_SERVER = '127.0.0.1:9160'
      DEFAULT_KEYSPACE = 'backend_testing'
      THRIFT_OPTIONS = {:retries => 2, :timeout => 40}
        

      def initialize(options)

        init_servers = options[:servers] || Array(DEFAULT_SERVER)
        init_keyspace = options[:keyspace] || DEFAULT_KEYSPACE
        
        super(init_servers,{:keyspace => init_keyspace}, THRIFT_OPTIONS)
        
      end

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
          execute_cql_query("truncate #{cf}")
        end
      end
      
      def add(column_family, row_key, value, col_key)
        execute_cql_query(add2cql(column_family, row_key, value, col_key))
      end
      
      def get(column_family, row_key, col_key)
        r = execute(get2cql(column_family, row_key, col_key))
        r.fetch do |row|
          return row.to_hash[col_key]
        end 
        return nil
      end
      
    end
  end
end
