module ThreeScale
  module Backend
    class StorageCassandra < ::CassandraCQL::Database
      include Configurable
      include Backend::Aggregator::StatsBatcher

      DEFAULT_SERVER = '127.0.0.1:9160'
      DEFAULT_KEYSPACE = 'backend_testing'
      
      ## WARNING: for the execute_cql_query (insterting batch) we do not want any timeout. If happens, we are 
      ## quite screwed, since it will raise exception but the data will have been processed by cassandra.
      ## retries makes it worse since we will be overcouinting x retries times more. 
      THRIFT_OPTIONS = {:retries => 2, :timeout => 60, :timeout_overrides => {:execute_cql_query => 0}}
        

      def initialize(options)

        init_servers = options[:servers] || Array(DEFAULT_SERVER)
        init_keyspace = options[:keyspace] || DEFAULT_KEYSPACE
        
        db = super(init_servers,{:keyspace => init_keyspace}, THRIFT_OPTIONS)
      
        #db.connection.add_callback(:on_exception) do |exception, method|
        #  if method.to_sym==:execute_cql_query && exception.message.match(/Socket: Timed out reading/)
            ## this should not happen, if so, we need to know
            ## TODO: launch an airbreak
        #  end
        #end
      
        db
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
