require_relative '../../acceptance_spec_helper'

resource 'Transactions (prefix: /services/:service_id/transactions)' do
  set_app(ThreeScale::Backend::API::Internal.new(allow_insecure: true))
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'

  let(:service_id) { '7575' }
  let(:non_existing_service_id) { service_id.to_i.succ.to_s }

  before do
    ThreeScale::Backend::TransactionStorage.delete_all(service_id)
    ThreeScale::Backend::Service.save!(provider_key: 'foo', id: service_id)
  end

  get '/services/:service_id/transactions/' do
    parameter :service_id, 'Service ID', required: true

    context 'when there are no transactions' do
      example_request 'Get the transactions by service ID' do
        expect(response_json['transactions']).to be_empty
        expect(response_status).to eq(200)
      end
    end

    context 'when the number of transactions is less than the established limit' do
      let(:test_time1) { Time.new(2014, 1, 1) }
      let(:test_time2) { Time.new(2015, 1, 1) }
      let(:test_transactions) do
        transactions = []
        transactions << ThreeScale::Backend::Transaction.new(
            service_id: service_id,
            application_id: 'test_application1_id',
            usage: 'test_usage_1',
            timestamp: test_time1)
        transactions << ThreeScale::Backend::Transaction.new(
            service_id: service_id,
            application_id: 'test_application2_id',
            usage: 'test_usage_2',
            timestamp: test_time2)
      end

      before do
        ThreeScale::Backend::TransactionStorage.store_all(test_transactions)
      end

      example_request 'Get the transactions by service ID' do
        expect(response_json['transactions'].size).to eq(test_transactions.size)

        last_transaction = response_json['transactions'][0]
        expect(last_transaction['application_id']).to eq(test_transactions[1].application_id)
        expect(last_transaction['usage']).to eq(test_transactions[1].usage)
        expect(last_transaction['timestamp']).to eq(test_transactions[1].timestamp.to_s)

        previous_transaction = response_json['transactions'][1]
        expect(previous_transaction['application_id']).to eq(test_transactions[0].application_id)
        expect(previous_transaction['usage']).to eq(test_transactions[0].usage)
        expect(previous_transaction['timestamp']).to eq(test_transactions[0].timestamp.to_s)

        expect(response_status).to eq(200)
      end
    end

    context 'when the number of transactions is higher than the limit' do
      let(:max_transactions) { ThreeScale::Backend::TransactionStorage.const_get(:LIMIT) }
      let(:test_transactions) do
        transactions = []
        (max_transactions + 1).times do
          transactions << ThreeScale::Backend::Transaction.new(
              service_id: service_id,
              application_id: 'test_application',
              usage: 'test_usage',
              timestamp: Time.now)
        end
        transactions
      end

      before do
        ThreeScale::Backend::TransactionStorage.store_all(test_transactions)
      end

      example_request 'Get the transactions by service ID' do
        expect(response_json['transactions'].size).to eq(max_transactions)
        expect(response_status).to eq(200)
      end
    end

    context 'with non-existing service ID' do
      example 'Try to get the transactions' do
        do_request(service_id: non_existing_service_id)
        expect(response_status).to eq(404)
      end
    end
  end

  post '/services/:service_id/transactions/' do
    parameter :service_id, 'Service ID', required: true
    parameter :transactions, 'Transactions', required: false

    let(:transactions_time) { Time.new(2015, 1, 1) }
    let(:transactions) do
      transactions = []
      5.times do
        transactions << { application_id: 'test_application',
                          usage: 'test_usage',
                          timestamp: transactions_time.to_s }
      end
      transactions
    end

    define_method :raw_post do
      params.to_json
    end

    context 'with existing service ID' do
      example_request 'Save transactions' do
        expect(ThreeScale::Backend::TransactionStorage.list(service_id).size)
            .to eq(transactions.size)

        # Check that the transactions has been saved. It is enough to check one
        # because all the example transactions used have the same attributes
        one_saved_transaction = ThreeScale::Backend::TransactionStorage.list(service_id).first
        expect(one_saved_transaction[:application_id])
            .to eq(transactions.last[:application_id])
        expect(one_saved_transaction[:usage])
            .to eq(transactions.last[:usage])
        expect(one_saved_transaction[:timestamp].localtime.to_s)
            .to eq(transactions.last[:timestamp])

        expect(response_status).to eq(201)
      end
    end

    context 'without transactions' do
      let(:transactions) { nil }

      example_request 'Try to save' do
        expect(response_status).to eq(400)
      end
    end

    context 'with non-existing service ID' do
      example 'Save transactions' do
        do_request(service_id: non_existing_service_id)
        expect(response_status).to eq(404)
      end
    end
  end

  delete '/services/:service_id/transactions/' do
    parameter :service_id, 'Service ID', required: true

    context 'when there are no transactions' do
      example_request 'Delete transactions' do
        expect(response_status).to eq(200)
        expect(ThreeScale::Backend::TransactionStorage.list(service_id)).to be_empty
      end
    end

    context 'when there are transactions' do
      let(:test_transactions) do
        transactions = []
        transactions << ThreeScale::Backend::Transaction.new(
            service_id: service_id,
            application_id: 'test_application1_id',
            usage: 'test_usage_1',
            timestamp: Time.now)
      end

      before do
        ThreeScale::Backend::TransactionStorage.store_all(test_transactions)
      end

      example_request 'Delete transactions' do
        expect(response_status).to eq(200)
        expect(ThreeScale::Backend::TransactionStorage.list(service_id)).to be_empty
      end
    end

    context 'with non-existing service ID' do
      example 'Delete transactions' do
        do_request(service_id: non_existing_service_id)
        expect(response_status).to eq(404)
      end
    end
  end
end
