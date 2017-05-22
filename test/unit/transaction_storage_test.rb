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

  def transaction(attrs = {})
    default_attrs = {
      service_id:     @service_id,
      application_id: @application_id,
    }
    Transaction.new(default_attrs.merge(attrs))
  end

  test '#store_all stores transactions to the storage' do
    service_id_one = @service_id
    service_id_two = next_id

    application_id_one = @application_id
    application_id_two = next_id

    metric_id_one = @metric_id
    metric_id_two = next_id

    TransactionStorage.store_all([
      transaction(service_id: service_id_one,
                  application_id: application_id_one,
                  usage: { metric_id_one => 1 },
                  timestamp: Time.utc(2010, 9, 10, 17, 4)),
      transaction(service_id: service_id_two,
                  application_id: application_id_two,
                  usage: { metric_id_two => 2 },
                  timestamp: Time.utc(2010, 9, 10, 17, 10)),
    ])

    # Service one
    expected = [{ application_id: application_id_one,
                  usage: { metric_id_one => 1 },
                  timestamp: Time.utc(2010, 9, 10, 17, 4) }]
    assert_equal expected, TransactionStorage.list(service_id_one)

    # Service two
    expected = [{ application_id: application_id_two,
                  usage: { metric_id_two => 2 },
                  timestamp: Time.utc(2010, 9, 10, 17, 10) }]
    assert_equal expected, TransactionStorage.list(service_id_two)
  end

  test '#store_all does not store more transactions than the limit specified' do
    limit = TransactionStorage.const_get(:LIMIT)
    storage = TransactionStorage.send(:storage)
    storage.expects(:lpush).times(limit)

    transactions = Array.new(limit + 1,
                             transaction(service_id: 'a_service_id',
                                         application_id: 'an_app_id',
                                         usage: { 'a_metric' => 1 },
                                         timestamp: Time.now))

    TransactionStorage.store_all(transactions)
  end

  test '#list returns transactions from the storage' do
    application_id_one = @application_id
    application_id_two = next_id

    transactions = [transaction(service_id: @service_id,
                                application_id: application_id_one,
                                usage: { @metric_id => 1 },
                                timestamp: '2010-09-10 11:00:00 UTC'),
                    transaction(service_id: @service_id,
                                application_id: application_id_two,
                                usage: { @metric_id => 2 },
                                timestamp: '2010-09-10 11:02:00 UTC')]

    TransactionStorage.store_all(transactions)

    expected = [
      {
        application_id: application_id_two,
        usage:          { @metric_id => 2 },
        timestamp:      Time.utc(2010, 9, 10, 11, 2),
      },
      {
        application_id: application_id_one,
        usage:          { @metric_id => 1 },
        timestamp:      Time.utc(2010, 9, 10, 11, 0),
      },
    ]

    assert_equal expected, TransactionStorage.list(@service_id)
  end

  test 'list returns previously stored transactions' do
    TransactionStorage.store(transaction(
                               usage:     { @metric_id => 7 },
                               timestamp: Time.utc(2010, 9, 10, 17, 29)),
                            )

    transactions = TransactionStorage.list(@service_id)
    assert_equal 1, transactions.size

    expected = {
      application_id: @application_id,
      usage:          { @metric_id => 7 },
      timestamp:      Time.utc(2010, 9, 10, 17, 29),
    }

    assert_equal expected, transactions[0]
  end

  test 'list returns the transactions in reverse-insertion order' do
    TransactionStorage.store(transaction(
                               usage:     { @metric_id => 1 },
                               timestamp: Time.utc(2010, 9, 10, 17, 31)),
                            )

    TransactionStorage.store(transaction(
                               usage:     { @metric_id => 2 },
                               timestamp: Time.utc(2010, 9, 10, 17, 32)),
                            )

    transactions = TransactionStorage.list(@service_id)
    assert_equal 2, transactions[0][:usage][@metric_id]
    assert_equal 1, transactions[1][:usage][@metric_id]
  end

  test 'keeps at most LIMIT transactions in the storage' do
    limit = TransactionStorage.const_get(:LIMIT)

    (limit + 1).times do
      TransactionStorage.store(transaction(
                                 usage:     { @metric_id => 1 },
                                 timestamp: Time.now.getutc),
                              )
    end

    assert_equal limit, TransactionStorage.list(@service_id).size
  end

  test 'when more than LIMIT transactions are in the storage, the oldest ones are discarded' do
    limit = TransactionStorage.const_get(:LIMIT)

    (limit + 1).times do |index|
      TransactionStorage.store(transaction(
                                 usage:     { @metric_id => index },
                                 timestamp: Time.now.getutc),
                              )
    end

    assert_equal limit, TransactionStorage.list(@service_id).first[:usage][@metric_id]
  end

  test '#delete_all' do
    5.times do
      TransactionStorage.store(
          transaction(service_id: @service_id,
                      usage: { @metric_id => 1 },
                      timestamp: Time.now.getutc))
    end

    assert_equal 5, TransactionStorage.list(@service_id).size

    TransactionStorage.delete_all(@service_id)

    assert_empty TransactionStorage.list(@service_id)
  end
end
