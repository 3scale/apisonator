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

      describe 'complete transactions' do
        before do
          @app_id_two = next_id
          @log1 = example_log
          @log2 = example_log({ application_id: @app_id_two })
          LogRequestStorage.store_all([@log1, @log2])
        end

        describe 'getting logs' do
          it 'returns proper transactions given the service ID' do
            LogRequestStorage.count_by_service(@service_id).should == 2
            list = LogRequestStorage.list_by_service(@service_id)
            list.size.should == 2
            list[1].should == @log1
            list[0].should == @log2
          end

          it 'returns empty list given a different service ID' do
            LogRequestStorage.count_by_service(next_id).should == 0
            LogRequestStorage.list_by_service(next_id).size.should == 0
          end

          it 'filters out transactions by the service and app IDs' do
            LogRequestStorage.count_by_application(@service_id, @application_id).
              should == 1
            list = LogRequestStorage.list_by_application(@service_id, @application_id)
            list.size.should == 1
            list[0].should == @log1
          end
        end

        describe 'deleting logs' do
          it 'given application IDs deletes only from per-app list' do
            LogRequestStorage.delete_by_application(@service_id, @app_id_two)
            LogRequestStorage.list_by_application(@service_id, @app_id_two).size.
              should == 0
            LogRequestStorage.list_by_service(@service_id).size.should == 2
          end

          it 'given another service ID doesn\'t delete anything' do
            LogRequestStorage.delete_by_service(next_id)
            LogRequestStorage.list_by_service(@service_id).size.should == 2
          end

          it 'given the service ID deletes only from per-service list' do
            LogRequestStorage.delete_by_service(@service_id)
            LogRequestStorage.list_by_service(@service_id).size.should == 0
            LogRequestStorage.list_by_application(@service_id, @app_id_two).size.
              should == 1
          end
        end
      end

      describe 'storing logs' do
        it 'respects the limits of the lists' do
          (LogRequestStorage::LIMIT_PER_SERVICE + LogRequestStorage::LIMIT_PER_APP).
            times { LogRequestStorage.store(example_log) }

          @storage.llen("logs/service_id:#{@service_id}").
            should == LogRequestStorage::LIMIT_PER_SERVICE
          @storage.llen("logs/service_id:#{@service_id}/app_id:#{@application_id}").
            should == LogRequestStorage::LIMIT_PER_APP
        end
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
        default_params.merge params
      end

    end
  end
end


