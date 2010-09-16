require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class TransactionStorageTest < Test::Unit::TestCase
  include TestHelpers::Sequences

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb
    
    @service_id     = next_id
    @application_id = next_id
    @metric_id      = next_id
  end

  test '#store_all stores transactions to the storage' do
    service_id_one = @service_id
    service_id_two = next_id

    application_id_one = @application_id
    application_id_two = next_id

    metric_id_one = @metric_id
    metric_id_two = next_id

    TransactionStorage.store_all([{:service_id     => service_id_one,
                                   :application_id => application_id_one,
                                   :usage          => {metric_id_one => 1},
                                   :timestamp      => Time.utc(2010, 9, 10, 17, 4)},
                                  {:service_id     => service_id_two,
                                   :application_id => application_id_two,
                                   :usage          => {metric_id_two => 2},
                                   :timestamp      => Time.utc(2010, 9, 10, 17, 10)}])

    # Service one
    transactions = @storage.lrange("transactions/service_id:#{service_id_one}", 0, -1)
    assert_equal 1, transactions.size

    expected = {'application_id' => application_id_one,
                'usage'          => {metric_id_one => 1},
                'timestamp'      => '2010-09-10 17:04:00 UTC'}

    assert_equal expected, Yajl::Parser.parse(transactions[0])
    
    # Service two
    transactions = @storage.lrange("transactions/service_id:#{service_id_two}", 0, -1)
    assert_equal 1, transactions.size

    expected = {'application_id' => application_id_two,
                'usage'          => {metric_id_two => 2},
                'timestamp'      => '2010-09-10 17:10:00 UTC'}

    assert_equal expected, Yajl::Parser.parse(transactions[0])
  end
  
  test '#list returns transactions from the storage' do
    application_id_one = @application_id
    application_id_two = next_id

    @storage.lpush("transactions/service_id:#{@service_id}", 
                   Yajl::Encoder.encode(:application_id => application_id_one,
                                        :usage          => {@metric_id => 1},
                                        :timestamp      => '2010-09-10 11:00:00 UTC'))

    @storage.lpush("transactions/service_id:#{@service_id}", 
                   Yajl::Encoder.encode(:application_id => application_id_two,
                                        :usage          => {@metric_id => 2},
                                        :timestamp      => '2010-09-10 11:02:00 UTC'))

    expected = [{:application_id => application_id_two,
                 :usage          => {@metric_id => 2},
                 :timestamp      => Time.utc(2010, 9, 10, 11, 2)},
                {:application_id => application_id_one,
                 :usage          => {@metric_id => 1},
                 :timestamp      => Time.utc(2010, 9, 10, 11, 0)}]

    assert_equal expected, TransactionStorage.list(@service_id)
  end

  test 'list returns previously stored transactions' do
    TransactionStorage.store(:service_id     => @service_id,
                             :application_id => @application_id,
                             :usage          => {@metric_id => 7},
                             :timestamp      => Time.utc(2010, 9, 10, 17, 29))

    transactions = TransactionStorage.list(@service_id)
    assert_equal 1, transactions.size

    expected = {:application_id => @application_id,
                :usage          => {@metric_id => 7},
                :timestamp      => Time.utc(2010, 9, 10, 17, 29)}

    assert_equal expected, transactions[0]
  end
  
  test 'list returns the transactions in reverse-insertion order' do
    TransactionStorage.store(:service_id     => @service_id,
                             :application_id => @application_id,
                             :usage          => {@metric_id => 1},
                             :timestamp      => Time.utc(2010, 9, 10, 17, 31))
    
    TransactionStorage.store(:service_id     => @service_id,
                             :application_id => @application_id,
                             :usage          => {@metric_id => 2},
                             :timestamp      => Time.utc(2010, 9, 10, 17, 32))

    transactions = TransactionStorage.list(@service_id)
    assert_equal 2, transactions[0][:usage][@metric_id]
    assert_equal 1, transactions[1][:usage][@metric_id]
  end

  test 'keeps at most 100 transactions in the storage' do
    110.times do 
      TransactionStorage.store(:service_id     => @service_id,
                               :application_id => @application_id,
                               :usage          => {@metric_id => 1},
                               :timestamp      => Time.now.getutc)
    end

    assert_equal 100, @storage.llen("transactions/service_id:#{@service_id}")
  end

  test 'when more than 100 transactions are in the storage, the oldest ones are discarded' do
    110.times do |index|
      TransactionStorage.store(:service_id     => @service_id,
                               :application_id => @application_id,
                               :usage          => {@metric_id => index},
                               :timestamp      => Time.now.getutc)
    end

    assert_equal 109, TransactionStorage.list(@service_id).first[:usage][@metric_id]
  end
end
