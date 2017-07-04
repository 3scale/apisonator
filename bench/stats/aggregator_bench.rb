include ThreeScale::Backend

module AggregatorBenchmark
  class Fixture
    attr_reader :storage

    def initialize
      @storage = Storage.instance true
      @storage.flushdb
      Memoizer.reset!
      seed_data
    end

    def transactions(n = 1)
      Array.new n, default_transaction
    end

    private

    def default_transaction_timestamp
      Time.utc(2010, 5, 7, 13, 23, 33)
    end

    def default_transaction_attrs
      {
        service_id:     1001,
        application_id: 2001,
        timestamp:      default_transaction_timestamp,
        usage:          { '3001' => 1 },
      }
    end

    def default_transaction(attrs = {})
      Transaction.new default_transaction_attrs.merge(attrs)
    end

    def seed_data
      master_service_id = ThreeScale::Backend.configuration.master_service_id
      Metric.save(
        service_id: master_service_id,
        id:         100,
        name:       'hits',
        children:   [
          Metric.new(id: 101, name: 'transactions/create_multiple'),
          Metric.new(id: 102, name: 'transactions/authorize')
        ])

      Metric.save(
        service_id: master_service_id,
        id:         200,
        name:       'transactions'
      )

      provider_key = "provider_key"
      metrics      = []

      2.times do |i|
        i += 1
        service_id = 1000 + i
        Service.save!(provider_key: provider_key, id: service_id)
        Application.save(service_id: service_id, id: 2000 + i, state: :live)
        metrics << Metric.save(service_id: service_id, id: 3000 + i, name: 'hits')
      end
    end
  end
  private_constant :Fixture

  def self.run
    fixt = Fixture.new
    xn1 = fixt.transactions 1
    xn10 = fixt.transactions 10
    xn100 = fixt.transactions 100
    xn1000 = fixt.transactions 1000

    Benchmark.ips do |x|
      x.report 'process    1 transactions' do
        Stats::Aggregator.process xn1
      end
      x.report 'process   10 transactions' do
        Stats::Aggregator.process xn10
      end
      x.report 'process  100 transactions' do
        Stats::Aggregator.process xn100
      end
      x.report 'process 1000 transactions' do
        Stats::Aggregator.process xn1000
      end
      x.compare!
    end
  end
end

AggregatorBenchmark.run
