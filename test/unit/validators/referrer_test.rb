require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Validators
  class ReferrerTest < Test::Unit::TestCase
    include TestHelpers::Sequences
    include Validators

    def setup
      Storage.instance(true).flushdb

      @service = Service.save!(:provider_key => 'a_provider_key',
                               :id => next_id,
                               :referrer_filters_required => true)

      @application = Application.save(:service_id => @service.id,
                                      :id => next_id,
                                      :state => :active)

      @status = Transactor::Status.new(:service => @service,
                                       :application => @application)
    end

    test 'succeeds if no referrer filter is defined and no referrer is passed' do
      assert Referrer.apply(@status, {})
    end

    test 'succeeds if no referrer filter is defined and blank referrer is passed' do
      assert Referrer.apply(@status, :referrer => '')
    end

    test 'succeeds if simple domain filter is defined and matching referrer is passed' do
      @application.create_referrer_filter('example.org')
      assert Referrer.apply(@status, :referrer => 'example.org')
    end

    test 'succeeds if wildcard filter is defined and matching referrer is passed' do
      @application.create_referrer_filter('*.example.org')

      assert Referrer.apply(@status, :referrer => 'foo.example.org')
      assert Referrer.apply(@status, :referrer => 'bar.example.org')
      assert Referrer.apply(@status, :referrer => 'foo.bar.example.org')
    end

    test 'succeeds if simple ip filter is defined and matching referrer is passed' do
      @application.create_referrer_filter('127.0.0.1')
      assert Referrer.apply(@status, :referrer => '127.0.0.1')
    end

    test 'succeeds if a referrer filter is defined and bypass string is passed' do
      @application.create_referrer_filter('example.org')
      assert Referrer.apply(@status, :referrer => '*')
    end

    test 'fails if referrer filter is defined but no referrer is passed' do
      @application.create_referrer_filter('example.org')

      assert !Referrer.apply(@status, {})

      assert_equal 'referrer_not_allowed', @status.rejection_reason_code
      assert_equal 'referrer is missing',  @status.rejection_reason_text
    end

    test 'fails if simple domain filter is defined but non-matching referrer is passed' do
      @application.create_referrer_filter('foo.example.org')

      assert !Referrer.apply(@status, :referrer => 'bar.example.org')

      assert_equal 'referrer_not_allowed',                      @status.rejection_reason_code
      assert_equal 'referrer "bar.example.org" is not allowed', @status.rejection_reason_text
    end

    test 'fails if wildcard filter is defined but non-matching referrer is passed' do
      @application.create_referrer_filter('*.example.org')

      assert !Referrer.apply(@status, :referrer => 'foo.example.com')
      assert !Referrer.apply(@status, :referrer => 'example.org')
    end

    test 'fails if simple ip filter is defined but non-matching referrer is passed' do
      @application.create_referrer_filter('127.0.0.1')
      assert !Referrer.apply(@status, :referrer => '127.0.0.2')
    end

    test 'dot in a filter matches only dot' do
      @application.create_referrer_filter('fo.example.org')

      assert !Referrer.apply(@status, :referrer => 'forexample.org')
    end

    # TODO: maybe filters like the ones in the following tests should not even be allowed.

    test 'filter is not a regular expression' do
      @application.create_referrer_filter('ba[rz].example.org')

      assert !Referrer.apply(@status, :referrer => 'bar.example.org')
      assert !Referrer.apply(@status, :referrer => 'baz.example.org')

      assert  Referrer.apply(@status, :referrer => 'ba[rz].example.org')
    end

    test 'filter works if it looks like a broken regular expression' do
      @application.create_referrer_filter('(example.org')

      assert Referrer.apply(@status, :referrer => '(example.org')
    end
  end
end
