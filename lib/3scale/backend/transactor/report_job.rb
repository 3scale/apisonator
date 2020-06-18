module ThreeScale
  module Backend
    module Transactor

      # Job for reporting transactions.
      class ReportJob < BackgroundJob
        @queue = :priority

        class << self
          def perform_logged(service_id, raw_transactions, _enqueue_time, context_info = {})
            context_info ||= {} # avoid nils potentially existing in older versions
            request_info = context_info['request'.freeze] || {}

            transactions = parse_transactions(service_id, raw_transactions, request_info)
            ProcessJob.perform(transactions) if !transactions.nil? && transactions.size > 0

            # Last field was logs.size. Set it to 0 until we modify our parsers.
            [true, "#{service_id} #{transactions.size} 0"]
          rescue Error => error
            ErrorStorage.store(service_id, error, context_info)
            [false, "#{service_id} #{error}"]
          rescue Exception => error
            if error.class == ArgumentError &&
                error.message == "invalid byte sequence in UTF-8"

              ErrorStorage.store(service_id, NotValidData.new, context_info)
              [false, "#{service_id} #{error}"]
            else
              raise error
            end
          end

          private

          def enqueue_time(args)
            args[2]
          end

          def parse_transactions(service_id, raw_transactions, request_info)
            transactions = []
            exts = request_info['extensions'.freeze]&.symbolize_names || {}

            group_by_application_id(service_id, raw_transactions) do |app_id, group|
              group.each do |raw_transaction|

                transaction = compose_transaction(service_id, app_id, raw_transaction, exts)
                log         = raw_transaction['log']

                transaction[:response_code] = log['code'] if transaction && log

                transactions << transaction if transaction
              end
            end

            transactions
          end

          def group_by_application_id(service_id, transactions, &block)
            return [] if transactions.empty?
            transactions = transactions.values if transactions.respond_to?(:values)
            transactions.group_by do |transaction|
              Application.extract_id!(service_id, transaction['app_id'], transaction['user_key'])
            end.each(&block)
          end

          def compose_transaction(service_id, app_id, raw_transaction, extensions)
            usage = raw_transaction['usage']

            if usage && !usage.empty?
              metrics = Metric.load_all(service_id)
              {
                service_id:     service_id,
                application_id: app_id,
                timestamp:      raw_transaction['timestamp'],
                usage:          metrics.process_usage(usage,
                                                      extensions[:flat_usage] == '1'),
              }
            end
          end
        end
      end
    end
  end
end
