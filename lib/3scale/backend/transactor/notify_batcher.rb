require 'resque'
require '3scale/backend/configuration'

module ThreeScale
  module Backend
    module Transactor

      # This module is responsible for scheduling Notify jobs. These jobs are
      # used to report the usage of some metrics specified in the master
      # account.
      # This module is only used when running the SaaS version, because in
      # on-premises, master accounts are disabled.
      module NotifyBatcher
        include Resque::Helpers
        include Backend::Configurable

        module SaaS
          METRIC_AUTHORIZE = 'transactions/authorize'.freeze
          METRIC_TRANSACTIONS = 'transactions'.freeze
          private_constant :METRIC_AUTHORIZE, :METRIC_TRANSACTIONS

          def notify_authorize(provider_key)
            notify(provider_key, METRIC_AUTHORIZE => 1)
          end

          def notify_authrep(provider_key, transactions)
            notify(provider_key, METRIC_AUTHORIZE => 1,
                                 METRIC_TRANSACTIONS => transactions)
          end

          def notify_report(provider_key, transactions)
            notify(provider_key, METRIC_TRANSACTIONS => transactions)
          end
        end
        private_constant :SaaS

        module OnPrem
          def notify_authorize(_provider_key); end
          def notify_authrep(_provider_key, _transactions); end
          def notify_report(_provider_key, _transactions); end
        end
        private_constant :OnPrem

        def self.included(base)
          mod = ThreeScale::Backend.configuration.saas ? SaaS : OnPrem
          base.include(mod)
        end

        def key_for_notifications_batch
          "notify/aggregator/batch"
        end

        def notify(provider_key, usage)
          # batch several notifications together so that we can process just one
          # job for a group of them.
          notify_batch(provider_key, usage)
        end

        def notify_batch(provider_key, usage)
          # discard seconds so that all the notifications are stored in the same
          # bucket, because aggregation is done at the minute level.
          tt = Time.now.getutc
          tt = tt - tt.sec

          encoded = Yajl::Encoder.encode({
            provider_key: provider_key,
            usage: usage,
            time: tt.to_s
          })

          num_elements = storage.rpush(key_for_notifications_batch, encoded)

          if (num_elements  % configuration.notification_batch) == 0
            # batch is full
            process_batch(num_elements)
          end
        end

        def get_batch(num_elements)
          storage.pipelined do
            storage.lrange(key_for_notifications_batch, 0, num_elements - 1)
            storage.ltrim(key_for_notifications_batch, num_elements, -1)
          end.first
        end

        def process_batch(num_elements)
          do_batch(get_batch num_elements)
        end

        def do_batch(list)
          all = Hash.new

          list.each do |item|
            obj = decode(item)

            provider_key = obj['provider_key'.freeze]
            time = obj['time'.freeze]
            usage = obj['usage'.freeze]

            if usage.nil?
              obj['usage'.freeze] = {}
            end

            bucket_key = "#{provider_key}-" << time
            bucket_obj = all[bucket_key]

            if bucket_obj.nil?
              all[bucket_key] = obj
            else
              bucket_usage = bucket_obj['usage'.freeze]

              usage.each do |metric_name, value|
                bucket_usage[metric_name] =
                  bucket_usage.fetch(metric_name, 0) + value.to_i
              end
            end
          end

          enqueue_ts = Time.now.utc.to_f

          all.each do |_, v|
            enqueue_notify_job(v['provider_key'.freeze],
                               v['usage'.freeze],
                               v['time'.freeze],
                               enqueue_ts)
          end
        end

        private

        def enqueue_notify_job(provider_key, usage, timestamp, enqueue_ts)
          ::Resque.enqueue(NotifyJob,
                           provider_key,
                           usage,
                           timestamp,
                           enqueue_ts)
        end

        if ThreeScale::Backend.test?
          module Test
            def get_full_batch
              storage.pipelined do
                storage.lrange(key_for_notifications_batch, 0, -1)
                storage.del(key_for_notifications_batch)
              end.first
            end

            def process_full_batch
              do_batch(get_full_batch)
            end
          end

          private_constant :Test

          include Test
        end
      end
    end
  end
end
