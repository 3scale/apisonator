require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Transactor
  class NotifyBatcherTest < Test::Unit::TestCase
    include TestHelpers::Sequences
    include Resque::Helpers

    def setup
      @storage = Storage.instance(true)
      @storage.flushdb
      Resque.reset!
    end

    test 'check the notify_batch are batched properly' do
      bkp_configuration = configuration.clone
      configuration.notification_batch = 100

      assert_equal 0, @storage.llen(Transactor.key_for_notifications_batch)

      Timecop.freeze(Time.utc(2010, 7, 29, 18, 21, 00)) do
        Transactor.notify_batch('foo', {'transactions/authorize' => 1})
        Transactor.notify_batch('bar', {'transactions/authorize' => 1})
      end

      Timecop.freeze(Time.utc(2010, 7, 29, 18, 21, 30)) do
        Transactor.notify_batch('foo', {'transactions/authorize' => 1})
        Transactor.notify_batch('bar', {'transactions/authorize' => 1})
      end

      Timecop.freeze(Time.utc(2010, 7, 29, 18, 21, 59)) do
        Transactor.notify_batch('foo', {'transactions/authorize' => 1, 'transactions/foo' => 1})
        Transactor.notify_batch('bar', {'transactions/authorize' => 1, 'transactions/bar' => 1})
      end

      Timecop.freeze(Time.utc(2010, 7, 29, 19, 22, 30)) do
        Transactor.notify_batch('foo', {'transactions/authorize' => 1})
        Transactor.notify_batch('bar', {'transactions/authorize' => 1})
      end

      assert_equal 8, @storage.llen(Transactor.key_for_notifications_batch)

      self.configuration = bkp_configuration
    end

    test 'check process_batch' do

      assert_equal 0, @storage.llen(Transactor.key_for_notifications_batch)
      assert_equal 0, Resque.queues[:main].size

      Timecop.freeze(Time.utc(2010, 7, 29, 18, 21, 00)) do
        Transactor.notify_batch('foo', {'transactions/authorize' => 1})
        Transactor.notify_batch('bar', {'transactions/authorize' => 1})
      end

      assert_equal 2, @storage.llen(Transactor.key_for_notifications_batch)
      assert_equal 0, Resque.queues[:main].size

      Timecop.freeze(Time.utc(2010, 7, 29, 18, 21, 30)) do
        Transactor.notify_batch('foo', {'transactions/authorize' => 1})
        Transactor.notify_batch('bar', {'transactions/authorize' => 1})
      end

      assert_equal 4, @storage.llen(Transactor.key_for_notifications_batch)
      assert_equal 0, Resque.queues[:main].size

      Timecop.freeze(Time.utc(2010, 7, 29, 18, 21, 59)) do
        Transactor.notify_batch('foo', {'transactions/authorize' => 1, 'transactions/foo' => 1})
        Transactor.notify_batch('bar', {'transactions/authorize' => 1, 'transactions/bar' => 1})
      end

      assert_equal 1, @storage.llen(Transactor.key_for_notifications_batch)
      assert_equal 2, Resque.queues[:main].size

      assert_equal '{"class":"ThreeScale::Backend::Transactor::NotifyJob","args":["foo",{"transactions/authorize":3,"transactions/foo":1},"2010-07-29 18:21:00 UTC",1280427719.0]}', Resque.queues[:main][0]
      assert_equal '{"class":"ThreeScale::Backend::Transactor::NotifyJob","args":["bar",{"transactions/authorize":2},"2010-07-29 18:21:00 UTC",1280427719.0]}', Resque.queues[:main][1]

      Timecop.freeze(Time.utc(2010, 7, 29, 19, 22, 30)) do
        Transactor.notify_batch('foo', {'transactions/authorize' => 1})
        Transactor.notify_batch('bar', {'transactions/authorize' => 1})
      end

      assert_equal 3, @storage.llen(Transactor.key_for_notifications_batch)
      assert_equal 2, Resque.queues[:main].size

      ## process one
      Transactor.process_batch(1)

      assert_equal 2, @storage.llen(Transactor.key_for_notifications_batch)
      assert_equal 3, Resque.queues[:main].size

      ## process all
      Transactor.process_full_batch

      assert_equal 0, @storage.llen(Transactor.key_for_notifications_batch)
      assert_equal 5, Resque.queues[:main].size

    end

    test 'check process_batch with large notification batch' do

      bkp_configuration = configuration.clone
      configuration.notification_batch = 100

      assert_equal 0, @storage.llen(Transactor.key_for_notifications_batch)

      Timecop.freeze(Time.utc(2010, 7, 29, 18, 21, 00)) do
        Transactor.notify_batch('foo', {'transactions/authorize' => 1})
        Transactor.notify_batch('bar', {'transactions/authorize' => 1})
      end

      Timecop.freeze(Time.utc(2010, 7, 29, 18, 21, 30)) do
        Transactor.notify_batch('foo', {'transactions/authorize' => 1})
        Transactor.notify_batch('bar', {'transactions/authorize' => 1})
      end

      Timecop.freeze(Time.utc(2010, 7, 29, 18, 21, 59)) do
        Transactor.notify_batch('foo', {'transactions/authorize' => 1, 'transactions/foo' => 1})
        Transactor.notify_batch('bar', {'transactions/authorize' => 1, 'transactions/bar' => 1})
      end

      Timecop.freeze(Time.utc(2010, 7, 29, 18, 22, 30)) do
        Transactor.notify_batch('foo', {'transactions/authorize' => 1})
        Transactor.notify_batch('bar', {'transactions/authorize' => 1})
      end

      Timecop.freeze(Time.utc(2010, 7, 29, 18, 22, 50)) do
        Transactor.notify_batch('foo', {'transactions/authorize' => 1})
        Transactor.notify_batch('bar', {'transactions/bar' => 1})
      end

      assert_equal 10, @storage.llen(Transactor.key_for_notifications_batch)

      Timecop.freeze(Time.utc(2010, 7, 29, 18, 22, 55)) do
        Transactor.process_full_batch
      end

      assert_equal 0, @storage.llen(Transactor.key_for_notifications_batch)
      assert_equal 4, Resque.queues[:main].size

      assert_equal '{"class":"ThreeScale::Backend::Transactor::NotifyJob","args":["foo",{"transactions/authorize":3,"transactions/foo":1},"2010-07-29 18:21:00 UTC",1280427775.0]}', Resque.queues[:main][0]
      assert_equal '{"class":"ThreeScale::Backend::Transactor::NotifyJob","args":["bar",{"transactions/authorize":3,"transactions/bar":1},"2010-07-29 18:21:00 UTC",1280427775.0]}', Resque.queues[:main][1]
      assert_equal '{"class":"ThreeScale::Backend::Transactor::NotifyJob","args":["foo",{"transactions/authorize":2},"2010-07-29 18:22:00 UTC",1280427775.0]}', Resque.queues[:main][2]
      assert_equal '{"class":"ThreeScale::Backend::Transactor::NotifyJob","args":["bar",{"transactions/authorize":1,"transactions/bar":1},"2010-07-29 18:22:00 UTC",1280427775.0]}', Resque.queues[:main][3]

      self.configuration = bkp_configuration
    end

    test 'does not batch anything when master service ID is not set' do
      original_config = configuration.clone

      [nil, ""].each do |master_service_id|
        configuration.master_service_id = master_service_id

        provider_key = 'some_provider_key'
        Transactor.notify_authorize(provider_key)
        Transactor.notify_authrep(provider_key, 1)
        Transactor.notify_report(provider_key, 1)

        assert_equal 0, @storage.llen(Transactor.key_for_notifications_batch) # nothing batched
        assert_equal 0, Resque.queues[:main].size # nothing enqueued
      end

      self.configuration = original_config
    end
  end
end

