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
          METRIC_CREATE_MULTIPLE = 'transactions/create_multiple'.freeze
          METRIC_TRANSACTIONS = 'transactions'.freeze
          private_constant :METRIC_AUTHORIZE, :METRIC_CREATE_MULTIPLE, :METRIC_TRANSACTIONS

          def notify_authorize(provider_key)
            notify(provider_key, METRIC_AUTHORIZE => 1)
          end

          def notify_authrep(provider_key, transactions)
            notify(provider_key, METRIC_AUTHORIZE => 1,
                                 METRIC_CREATE_MULTIPLE => 1,
                                 METRIC_TRANSACTIONS => transactions)
          end

          def notify_report(provider_key, transactions)
            notify(provider_key, METRIC_CREATE_MULTIPLE => 1,
                                 METRIC_TRANSACTIONS => transactions)
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
          ## No longer create a job, but for efficiency the notify jobs (incr stats for the master) are
          ## batched. It used to be like this:
          ## tt = Time.now.getutc
          ## Resque.enqueue(NotifyJob, provider_key, usage, encode_time(tt), tt.to_f)
          ##
          ## Basically, instead of creating a NotifyJob directly, which would trigger between 10-20 incrby
          ## we store the data of the job in redis on a list. Once there are configuration.notification_batch
          ## on the list, the worker will fetch the list, aggregate them in a single NotifyJob will all the
          ## sums done in memory and schedule the job as a NotifyJob. The advantage is that instead of having
          ## 20 jobs doing 10 incrby of +1, you will have a single job doing 10 incrby of +20
          notify_batch(provider_key, usage)
        end

        def notify_batch(provider_key, usage)
          ## remove the seconds, so that all are stored in the same bucket, aggregation is done at the minute level
          tt = Time.now.getutc
          tt = tt-tt.sec

          encoded = Yajl::Encoder.encode({:provider_key => provider_key, :usage => usage, :time => encode_time(tt)})
          num_elements = storage.rpush(key_for_notifications_batch, encoded)

          if (num_elements  % configuration.notification_batch) == 0
            ## we have already a full batch, we have to create the NotifyJobs for the backend 
            process_batch(num_elements)
          end
        end

        def process_batch(num_elements, options = {})
          tt = Time.now
          all = Hash.new

          if options[:all]==true
            list = storage.lrange(key_for_notifications_batch,0,-1)
            storage.del(key_for_notifications_batch)
          else
            list = storage.lrange(key_for_notifications_batch,0,num_elements-1)
            storage.ltrim(key_for_notifications_batch,num_elements,-1)
          end

          list.each do |item|
            obj = decode(item)

            bucket_key = "#{obj['provider_key']}-#{obj['time']}"

            all[bucket_key] = {"provider_key" => obj["provider_key"], "time" => obj["time"], "usage" => {}} if all[bucket_key].nil?

            obj["usage"].each do |metric_name, value|
              value = value.to_i
              all[bucket_key]["usage"][metric_name] ||= 0
              all[bucket_key]["usage"][metric_name] += value
            end
          end

          all.each do |_, v|
            ::Resque.enqueue(NotifyJob, v["provider_key"], v["usage"], encode_time(v["time"]), tt.to_f)
          end
        end

        private

        def encode_time(time)
          time.to_s
        end
      end

    end
  end
end
