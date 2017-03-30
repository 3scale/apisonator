module ThreeScale
  module Backend
    module Transactor

      # Job to process the api calls between buyer and provider
      class LogRequestJob < BackgroundJob
        @queue = :main

        class << self
          def perform_logged(service_id, logs, _enqueue_time)
            logs = preprocess(logs)
            LogRequestStorage.store_all(logs)
            [true, "#{service_id} #{logs.size}"]
          end

          private

          def preprocess(logs)
            logs.map do |log|
              log = log.symbolize_names
              log[:timestamp] = parse_timestamp(log[:timestamp])
              log[:log] = clean_entry_log(log[:log])
              log[:usage] = clean_entry_usage(log[:usage])
              log
            end
          end

          ## convert usage to string, just for display
          def clean_entry_usage(entry)
            return "N/A" if entry.nil? || entry.empty?
            s = ""
            entry.each do |k, v|
              s << "#{k}: #{v}, "
            end
            return s
          end

          def clean_entry_log(entry)
            entry['code'] = "N/A" if entry['code'].nil? || entry['code'].empty?
            entry['request'] = "N/A" if entry['request'].nil? || entry['request'].empty?
            entry['response'] = "N/A" if entry['response'].nil? || entry['response'].empty?

            entry['request'] = entry['request'][0..LogRequestStorage::ENTRY_MAX_LEN_REQUEST] + LogRequestStorage::TRUNCATED if entry['request'].size > LogRequestStorage::ENTRY_MAX_LEN_REQUEST
            entry['response'] = entry['response'][0..LogRequestStorage::ENTRY_MAX_LEN_RESPONSE] + LogRequestStorage::TRUNCATED if entry['response'].size > LogRequestStorage::ENTRY_MAX_LEN_RESPONSE
            entry['code'] = entry['code'][0..LogRequestStorage::ENTRY_MAX_LEN_CODE] + LogRequestStorage::TRUNCATED if  entry['code'].size > LogRequestStorage::ENTRY_MAX_LEN_CODE

            entry
          end

          def parse_timestamp(timestamp)
            return timestamp if timestamp.is_a?(Time)
            ts = Time.parse_to_utc(timestamp)
            if ts.nil?
              return Time.now.getutc
            else
              return ts
            end
          end
        end
      end
    end
  end
end
