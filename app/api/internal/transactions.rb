module ThreeScale
  module Backend
    module API
      internal_api '/services/:service_id/transactions' do
        before do
          unless Service.exists?(params[:service_id])
            respond_with_404('service not found')
          end
        end

        get '/' do |service_id|
          transactions = TransactionStorage.list(service_id)

          # The timestamps are saved in UTC format.
          # We convert them to localtime to use the same format as the XML API.
          transactions.each do |transaction|
            transaction[:timestamp] = transaction[:timestamp].localtime.to_s
          end

          { status: :found, transactions: transactions }.to_json
        end

        if define_private_endpoints?
          post '/' do |service_id|
            transactions = params[:transactions]

            unless transactions
              halt 400, { status: :error,
                          error: 'missing parameter \'transactions\'' }.to_json
            end

            transactions = transactions.map do |transaction|
              Transaction.new(service_id: service_id,
                              application_id: transaction[:application_id],
                              usage: transaction[:usage],
                              timestamp: transaction[:timestamp])
            end

            TransactionStorage.store_all(transactions)
            [201, headers, { status: :created }.to_json]
          end

          delete '/' do |service_id|
            TransactionStorage.delete_all(service_id)
            { status: :deleted }.to_json
          end
        end
      end
    end
  end
end
