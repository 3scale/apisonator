require_relative '../spec_helper'

module ThreeScale
  module Backend
    describe LogRequestStorage do
      include TestHelpers::Sequences

      before do
        @storage = Storage.instance(true)
        @storage.flushdb
        @service_id, @application_id, @metric_id = (1..3).map{ next_id }
      end

      it 'respects the limits of the lists' do
        (LogRequestStorage::LIMIT_PER_SERVICE + LogRequestStorage::LIMIT_PER_APP).
          times { LogRequestStorage.store(example_log) }

        @storage.llen("logs/service_id:#{@service_id}").
          should == LogRequestStorage::LIMIT_PER_SERVICE
        @storage.llen("logs/service_id:#{@service_id}/app_id:#{@application_id}").
          should == LogRequestStorage::LIMIT_PER_APP
      end

      private

      def example_log(params = {})
        default_params = {
          service_id: @service_id,
          application_id: @application_id,
          usage: {"metric_id_one" => 1},
          timestamp: Time.utc(2010, 9, 10, 17, 4),
          log: {'request' => 'req', 'response' => 'resp', 'code' => 200}
        }
        params.merge default_params
      end

    end
  end
end


