module ThreeScale
  module Backend
    module Transactor

      # Job to process the api calls between buyer and provider
      class LogRequestJob < BackgroundJob
        @queue = :main

        def self.perform_logged(transactions, enqueue_time)
          transactions = preprocess(transactions)
          LogRequestStorage.store_all(transactions)
        end

        private

        def self.preprocess(transactions)
          transactions.map do |transaction|
            transaction = transaction.symbolize_keys
            transaction[:timestamp] = parse_timestamp(transaction[:timestamp])
            transaction[:log] = clean_entry_log(transaction[:log])
            transaction[:usage] = clean_entry_usage(transaction[:usage])
            transaction
          end
        end

        ## convert usage to string, just for display
        def self.clean_entry_usage(entry)
          return "N/A" if entry.nil? || entry.empty?
          s = ""
          entry.each do |k, v|
            s << "#{k}: #{v}, "
          end
          return s
        end

        def self.clean_entry_log(entry)
          entry['code'] = "N/A" if entry['code'].nil? || entry['code'].empty?
          entry['request'] = "N/A" if entry['request'].nil? || entry['request'].empty?
          entry['response'] = "N/A" if entry['response'].nil? || entry['response'].empty?

          entry['request'] = entry['request'][0..LogRequestStorage::ENTRY_MAX_LEN_REQUEST] + LogRequestStorage::TRUNCATED if entry['request'].size > LogRequestStorage::ENTRY_MAX_LEN_REQUEST
          entry['response'] = entry['response'][0..LogRequestStorage::ENTRY_MAX_LEN_RESPONSE] + LogRequestStorage::TRUNCATED if entry['response'].size > LogRequestStorage::ENTRY_MAX_LEN_RESPONSE
          entry['code'] = entry['code'][0..LogRequestStorage::ENTRY_MAX_LEN_CODE] + LogRequestStorage::TRUNCATED if  entry['code'].size > LogRequestStorage::ENTRY_MAX_LEN_CODE

          entry
        end

        def self.parse_timestamp(timestamp)
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
