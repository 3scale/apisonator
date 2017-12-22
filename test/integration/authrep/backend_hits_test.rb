require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class AuthrepBackendHitsTest < Test::Unit::TestCase
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Fixtures
  include TestHelpers::Integration
  include TestHelpers::StorageKeys

  include TestHelpers::AuthRep

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    Resque.reset!
    Memoizer.reset!

    setup_oauth_provider_fixtures

    @application = Application.save(:service_id => @service.id,
                                    :id         => next_id,
                                    :state      => :active,
                                    :plan_id    => @plan_id,
                                    :plan_name  => @plan_name)

    @metric_id = next_id
    Metric.save(:service_id => @service.id, :id => @metric_id, :name => 'hits')
  end

  test_authrep 'successful authorize reports backend hit' do |e|
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      get e, :provider_key => @provider_key,
             :app_id       => @application.id

      Resque.run!
      ## processes all the pending NotifyJobs. This creates a NotifyJob with the
      ## aggregate and another Resque.run! is needed
      Backend::Transactor.process_full_batch
      Resque.run!

      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_hits_id,
                                                   :month, '20100501')).to_i

      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_authorizes_id,
                                                   :month, '20100501')).to_i
    end
  end

  test_authrep 'authorize with invalid provider key does not report backend hit' do |e|
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      get e, :provider_key => 'boo',
             :app_id       => @application.id
      Resque.run!

      Backend::Transactor.process_full_batch
      Resque.run!

      assert_equal 0, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_authorizes_id,
                                                   :month, '20100501')).to_i
    end
  end

  test_authrep 'authorize with invalid application id reports backend hit' do |e|
    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      get e, :provider_key => @provider_key,
             :app_id       => 'baa'
      Resque.run!

      Backend::Transactor.process_full_batch
      Resque.run!

      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_authorizes_id,
                                                   :month, '20100501')).to_i
    end
  end

  test_authrep 'authorize with inactive application reports backend hit' do |e|
    @application.state = :suspended
    @application.save

    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      get e, :provider_key => @provider_key,
             :app_id       => @application.id

      Resque.run!

      Backend::Transactor.process_full_batch
      Resque.run!

      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_authorizes_id,
                                                   :month, '20100501')).to_i
    end
  end

  test_authrep 'authorize with exceeded usage limits reports backend hit' do |e|
    UsageLimit.save(:service_id => @service_id,
                    :plan_id    => @plan_id,
                    :metric_id  => @metric_id,
                    :day        => 4)

    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      Transactor.report(@provider_key, @service_id,
                        0 => {'app_id' => @application.id, 'usage' => {'hits' => 5}})
      Resque.run!

      Backend::Transactor.process_full_batch
      Resque.run!
    end

    Timecop.freeze(Time.utc(2010, 5, 12, 13, 33)) do
      get e, :provider_key => @provider_key,
             :app_id       => @application.id
      Resque.run!

      Backend::Transactor.process_full_batch
      Resque.run!

      assert_equal 1, @storage.get(application_key(@master_service_id,
                                                   @provider_application_id,
                                                   @master_authorizes_id,
                                                   :month, '20100501')).to_i
    end
  end
end
