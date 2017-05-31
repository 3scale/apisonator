module ThreeScale
  module Backend
    module Transactor

      # Job for reporting transactions.
      class ReportJob < BackgroundJob
        @queue = :priority

        class << self
          def perform_logged(service_id, raw_transactions, _enqueue_time, context_info = {})
            transactions = parse_transactions(service_id, raw_transactions)
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

          def enqueue_time
            @args[2]
          end

          def parse_transactions(service_id, raw_transactions)
            transactions = []

            group_by_application_id(service_id, raw_transactions) do |app_id, group|
              group.each do |raw_transaction|
                check_end_users_allowed(raw_transaction, service_id)

                transaction = compose_transaction(service_id, app_id, raw_transaction)
                log         = raw_transaction['log']

                transaction[:response_code] = log[:log]['code'] if transaction && log

                transactions << transaction if transaction
              end
            end

            transactions
          end

          def group_by_application_id(service_id, transactions, &block)
            return [] if transactions.empty?
            transactions = transactions.values if transactions.respond_to?(:values)
            transactions.group_by do |transaction|
              Application.extract_id!(service_id, transaction['app_id'], transaction['user_key'], transaction['access_token'])
            end.each(&block)
          end

          def check_end_users_allowed(raw_transaction, service_id = nil)
            user_id = raw_transaction['user_id']

            if service_id && user_id && !user_id.empty? && !end_users_allowed?(service_id)
              raise ServiceCannotUseUserId.new(service_id)
            end
          end

          def end_users_allowed?(service_id)
            service = Service.load_by_id(service_id)
            !(service &&
              service.user_registration_required? &&
              service.default_user_plan_id.nil?)
          end

          def compose_transaction(service_id, app_id, raw_transaction)
            usage = raw_transaction['usage']

            if usage && !usage.empty?
              metrics = Metric.load_all(service_id)
              {
                service_id:     service_id,
                application_id: app_id,
                timestamp:      raw_transaction['timestamp'],
                usage:          metrics.process_usage(usage),
                user_id:        raw_transaction['user_id'],
              }
            end
          end
        end
      end
    end
  end
end
