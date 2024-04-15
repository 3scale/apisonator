class AggregatorBenchmark
  include TestHelpers::Fixtures

  def run
    Memoizer.reset!
    storage(true).flushdb
    seed_data

    xn1 = [transaction_with_response_code]
    xn10 = Array.new 10, transaction_with_response_code
    xn100 = Array.new 100, transaction_with_response_code
    xn1000 = Array.new 1000, transaction_with_response_code

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

AggregatorBenchmark.new.run
