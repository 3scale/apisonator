module ThreeScale
  module Backend
    module Transactor
      # Job for processing (aggregating and archiving) transactions.

      ## WARNING: This is not a resque job, the .perform is called by another job, either Report or NotifyJob
      ## it's meant to be like this in case we want to deatach it further
      class ProcessJob
        #@queue = :main

        def self.perform(transactions, options={})
          transactions = preprocess(transactions)
          TransactionStorage.store_all(transactions) unless options[:master]
          Aggregator.aggregate_all(transactions)
          Archiver.add_all(transactions) unless options[:master]
        end

        def self.preprocess(transactions)
          transactions.map do |transaction|
            transaction = transaction.symbolize_keys
            current_time = Time.now.getutc
            transaction[:timestamp] = parse_timestamp(transaction[:timestamp])
            ## check if the timestamps is within accepted range
            ## CAUTION:
            ## if this fails on tests and don't know why, do not that notifyjobs are batched!!
            ## therefore on the test environment playing with timecop can have some nasty effects
            ## batching jobs across multiple days and consenquently raising this error,
            ## Backend::Transactor.process_batch(0,{:all => true}); Resque.run!
            if (current_time - transaction[:timestamp]) > REPORT_DEADLINE
              begin
                raise ReportTimestampNotWithinRange.new
                ##RIGHT NOW ONLY RAISE AN AIRBREAK TO KNOW IF SOMEONE DOES IT, once active, remove
                ##the rescue and the aibrake notify
                ##test_aggregates_failure_due_to_report_after_deadline(Transactor::ProcessJobTest) [/Users/solso/3scale/backend/test/unit/transactor/process_job_test.rb
                ##report cannot use an explicit timestamp older than 24 hours(ReportTest) [/Users/solso/3scale/backend/test/integration/report_test.rb
              rescue Error => e
              end
            end
            transaction
          end
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
