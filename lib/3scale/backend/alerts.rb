
module ThreeScale
  module Backend
    module Alerts

      def utilization(status)
        max_utilization = -1.0
        max_record = nil

        status.usage_reports.each do |item|         
          utilization = item.current_value / item.max_value.to_f if item.max_value>0
          if utilization > max_utilization
            max_record = item
            max_utilization = utilization
          end
        end

        status.user_usage_reports.each do |item|
          utilization = item.current_value / item.max_value.to_f if item.max_value>0
          if utilization > max_utilization
            max_record = item
            max_utilization = utilization
          end
        end
        [max_utilization, max_record]
      end

      def update_utilization(status, max_utilization, max_record, timestamp)

        discrete = (max_utilization*10).to_i
        discrete = 10 if discrete > 10
       
        period0 = timestamp.beginning_of_cycle(:day)
        period1 = (timestamp-3600*24).beginning_of_cycle(:day)
          
        key0 = "alerts/service_id:#{status.application.service_id}/app_id:#{status.application.id}/#{period0}/#{discrete}"
        key1 = "alerts/service_id:#{status.application.service_id}/app_id:#{status.application.id}/#{period1}/#{discrete}"

        res = storage.pipelined do 
          storage.incrby(key1,"1")
          storage.get(key0)
        end
        
        ## fake notifications levels
        if res[0]==1 && (res[1].nil? || res[1]==0)
          if discrete==10
            ##puts "\n\n NOTIFICATION: VIOLATION 100% UTILIZATION \n\n"

          elsif discrete==9
            ##puts "\n\n NOTIFICATION: 90% UTILIZATION \n\n"
          end 
        end

      end

    end
  end
end
