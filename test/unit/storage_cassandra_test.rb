require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class StorageCassandraTest < Test::Unit::TestCase
 
  def setup
    @storage = StorageCassandra.instance(true)
    
    assert_equal @storage.keyspace, StorageCassandra::DEFAULT_KEYSPACE
    
    @storage.clear_keyspace!
    
  end

  def test_basic_operations
      
    @storage.add(:Stats, "row_key", 10, "column_key")
    assert_equal 10, @storage.get(:Stats, "row_key", "column_key")
    
    @storage.add(:Stats, "row_key", 5, "column_key")
    assert_equal 15, @storage.get(:Stats, "row_key", "column_key")
    
    @storage.add(:Stats, "row_key", -2, "column_key")
    assert_equal 13, @storage.get(:Stats, "row_key", "column_key")
    
    @storage.add(:Stats, "row_key", [-2, 42, 888], ["column_key", "column_key2", "column_key3"])
    assert_equal 11, @storage.get(:Stats, "row_key", "column_key")
    assert_equal 42, @storage.get(:Stats, "row_key", "column_key2")
    assert_equal 888, @storage.get(:Stats, "row_key", "column_key3")
    
    @storage.clear_keyspace!
    assert_equal nil, @storage.get(:Stats, "row_key", "column_key")
    
    assert_equal nil, @storage.get("Stats", "bullshit", "bullshit")
    
  end
  
  def test_addcql
    
    s = Aggregator.add2cql(:Stats, "row_key", 10, "column_key")
    assert_equal "UPDATE Stats SET 'column_key'='column_key' + 10 WHERE key = 'row_key';", s
    
    s = Aggregator.add2cql(:Stats, "row_key", [10, 11], ["ck1", "ck2"])
    assert_equal "UPDATE Stats SET 'ck1'='ck1' + 10, 'ck2'='ck2' + 11 WHERE key = 'row_key';", s
    
    s = Aggregator.add2cql(:Stats, "row_key", [10, 11, 12], ["ck1", "ck2", "ck3"])
    assert_equal "UPDATE Stats SET 'ck1'='ck1' + 10, 'ck2'='ck2' + 11, 'ck3'='ck3' + 12 WHERE key = 'row_key';", s
    
    assert_raise Exception do
      Aggregator.add2cql(:Stats, "row_key", [10, 11, 12], ["ck1"])
    end
    
    assert_raise Exception do
      Aggregator.add2cql(:Stats, "row_key", [10, 11, 12], "ck1")
    end

    assert_raise Exception do
      Aggregator.add2cql(:Stats, "row_key", [], [])
    end
    
  end
  
  
  def test_behaviour_of_cql_sentences
    
    ## single 
    
    @storage.execute("UPDATE Stats SET col = col + 1 WHERE key = row;")  
    assert_equal 1, @storage.get(:Stats, "row", "col")
    
    # well formed batch
    
    str = "BEGIN BATCH "
    10.times do 
      str << "UPDATE Stats SET col = col + 1 WHERE key = row;"
    end
    str << "APPLY BATCH;"
    
    @storage.execute(str)
    assert_equal 11, @storage.get(:Stats, "row", "col")
    
    # not well formed batch, if one fails in the middle, no increment is done
    # it's not transactional though!!
    
    str = "BEGIN BATCH "
    10.times do |i|
      if i==6
        str << "UPDATE FAKE SET col = col + 1 WHERE key = row;"
      else  
        str << "UPDATE Stats SET col = col + 1 WHERE key = row;"
      end
    end
    
    str << "APPLY BATCH;"
    
    assert_raise CassandraCQL::Error::InvalidRequestException do
      @storage.execute(str)
    end
    
    assert_equal 11, @storage.get(:Stats, "row", "col")
    
    # another  not well formed batch, 
    
    str = "BEGIN BATCH "
    10.times do |i|
      if i==6
        str << "bullshit; "
      else  
        str << "UPDATE Stats SET col = col + 1 WHERE key = row;"
      end
    end
    
    str << "APPLY BATCH;"
    
    assert_raise CassandraCQL::Error::InvalidRequestException do
      @storage.execute(str)
    end
    
    assert_equal 11, @storage.get(:Stats, "row", "col")
  
    
  end
  
  def test_failures_on_connections
    
    ## pretend that cassandra is not running (note the intentionally wrong port)
    
    bkp_configuration  = configuration.clone
    
    configuration.cassandra.servers = ["localhost:9090"]
    configuration.cassandra.keyspace = StorageCassandra::DEFAULT_KEYSPACE
    
    ## this is fine because it's the good instance from the setup
    storage = StorageCassandra.instance
    assert_not_nil storage
    assert_equal storage.connection.current_server.to_s, StorageCassandra::DEFAULT_SERVER
    
    ## but now it shouldn't because we are reloading.
    
    assert_raise ThriftClient::NoServersAvailable do 
      
      storage = StorageCassandra.instance(true)
    
    end
    
    ## it should not blow when we provide backup servers. 2 fakes and one real.
    
    configuration.cassandra.servers = ["localhost:9090", "localhost:9092", StorageCassandra::DEFAULT_SERVER]
    configuration.cassandra.keyspace = StorageCassandra::DEFAULT_KEYSPACE
    
    storage = StorageCassandra.instance(true)
    assert_not_nil storage
    assert_equal storage.connection.current_server.to_s, StorageCassandra::DEFAULT_SERVER
  
    storage.add(:Stats, "row_key", 10, "column_key")
    assert_equal 10, storage.get(:Stats, "row_key", "column_key")
    
  end
  
 
 
end


