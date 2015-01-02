module ThreeScale
  module Backend
    module Transactor

      # Job for reporting transactions.
      class ReportJob < BackgroundJob
        @queue = :priority

        def self.perform_logged(service_id, raw_transactions, enqueue_time)
          transactions, logs = parse_transactions(service_id, raw_transactions)
          ProcessJob.perform(transactions) if !transactions.nil? && transactions.size > 0
          unless logs.nil? || logs.empty?
            Resque.enqueue(LogRequestJob, service_id, logs, Time.now.getutc.to_f)
          end

          @success_log_message = "#{service_id} #{transactions.size} #{logs.size} "

        rescue ThreeScale::Core::Error, Error => error
          ErrorStorage.store(service_id, error)
          @error_log_message = "#{service_id} #{error}"
        rescue Exception => error
          if error.class == ArgumentError &&
              error.message == "invalid byte sequence in UTF-8"

            ErrorStorage.store(service_id, NotValidData.new)
            @error_log_message = "#{service_id} #{error}"
          else
            raise error
          end
        end

        private

        def self.parse_transactions(service_id, raw_transactions)
          transactions      = []
          logs              = []
          metrics           = nil
          end_users_allowed = nil

          group_by_application_id(service_id, raw_transactions) do |application_id, group|
            group.each do |raw_transaction|
              user_id = raw_transaction['user_id']
              if !service_id.nil? && !user_id.nil? && !user_id.empty? && end_users_allowed.nil?
                end_users_allowed = end_users_allowed?(service_id)
                raise ServiceCannotUseUserId.new(service_id) if !end_users_allowed
              end

              usage = raw_transaction['usage']

              if !usage.nil? && !usage.empty?
                metrics ||= Metric.load_all(service_id)
                # makes no sense to process a transaction if no usage is passed
                transactions << {
                  :service_id     => service_id,
                  :application_id => application_id,
                  :timestamp      => raw_transaction['timestamp'],
                  :usage          => metrics.process_usage(raw_transaction['usage']),
                  :user_id        => raw_transaction['user_id']}
              end

              r = raw_transaction['log']
              if !r.nil? && !r.empty? && !r['request'].nil?
                # here we don't care about the usage, but log needs to be passed
                logs << {
                  :service_id     => service_id,
                  :application_id => application_id,
                  :timestamp      => raw_transaction['timestamp'],
                  :log            => raw_transaction['log'],
                  :usage          => raw_transaction['usage'],
                  :user_id        => raw_transaction['user_id']
                }
              end

            end
          end

          [transactions, logs]
        end

        def self.group_by_application_id(service_id, transactions, &block)
          return [] if transactions.empty?
          transactions = transactions.values if transactions.respond_to?(:values)
          transactions.group_by do |transaction|
            Application.extract_id!(service_id, transaction['app_id'], transaction['user_key'], transaction['access_token'])
          end.each(&block)
        end

        def self.end_users_allowed?(service_id)
          service = Service.load_by_id(service_id)
          !(service &&
            service.user_registration_required? &&
            service.default_user_plan_id.nil?)
        end
      end
    end
  end
end
