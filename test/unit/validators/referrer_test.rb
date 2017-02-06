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

    test 'succeeds when service does not require referrer filters' do
      service_no_filters = Service.save!(:provider_key => 'a_provider_key',
                                         :id => next_id,
                                         :referrer_filters_required => false)

      app = Application.save(:service_id => service_no_filters.id,
                             :id => next_id,
                             :state => :active)

      status = Transactor::Status.new(:service => service_no_filters,
                                      :application => app)

      app.create_referrer_filter('accepted.org')

      assert Referrer.apply(status, :referrer => 'unaccepted.org')
    end

    test 'fails if the referrer matches the filter but with extra chars at the beginning' do
      @application.create_referrer_filter('1.2.3.4')
      assert !Referrer.apply(@status, :referrer => '231.2.3.4')
    end

    test 'fails if the referrer matches the filter but with extra chars at the end' do
      @application.create_referrer_filter('1.2.3.4')
      assert !Referrer.apply(@status, :referrer => '1.2.3.456')
    end

    test 'fails if the referrer matches the filter but with an extra \n' do
      @application.create_referrer_filter('1.2.3.4')
      assert !Referrer.apply(@status, :referrer => "1.2.3.4\n")
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

    test 'filters can be used for ignoring parts of the URI (scheme, path, etc.)' do
      @application.create_referrer_filter('*://example.com')
      @application.create_referrer_filter('http://8.8.8.8/*')

      assert Referrer.apply(@status, :referrer => 'http://example.com')
      assert Referrer.apply(@status, :referrer => 'https://example.com')
      assert !Referrer.apply(@status, :referrer => 'example.com')

      assert Referrer.apply(@status, :referrer => 'http://8.8.8.8/some/path')
      assert Referrer.apply(@status, :referrer => 'http://8.8.8.8/path?qs=value')
    end

    # this mostly is for documentation purposes but also to notice changes in
    # semantics.
    test 'filter works in stupid edge cases even though we would want to fix em some day' do
      @application.create_referrer_filter('194.179.*.10')
      @application.create_referrer_filter('8.8.8.*')
      @application.create_referrer_filter('*.3scale.net')

      assert Referrer.apply(@status, :referrer => '194.179..10')
      assert Referrer.apply(@status, :referrer => '194.179.OlaKeAse.10')
      assert Referrer.apply(@status, :referrer => '194.179.10.10.10.10')
      assert Referrer.apply(@status, :referrer => '194.179.999.10')

      assert Referrer.apply(@status, :referrer => '8.8.8.amazon-aws.com')
      assert Referrer.apply(@status, :referrer => '8.8.8.8:443')
      assert Referrer.apply(@status, :referrer => '8.8.8.8/some/path?qs=lol')

      assert Referrer.apply(@status, :referrer => '.3scale.net')
      assert Referrer.apply(@status, :referrer => 'https://OlaKeAse.3scale.net')
    end

    test 'apply fails if the referrer matches with extra chars at the beginning' do
      @application.create_referrer_filter('1.2.3.4')
      assert !Referrer.apply(@status, :referrer => '231.2.3.4')
    end

    test 'apply fails if the referrer matches with extra chars at the end' do
      @application.create_referrer_filter('1.2.3.4')
      assert !Referrer.apply(@status, :referrer => '1.2.3.456')
    end

    test 'apply fails if the referrer matches with an extra \n' do
      @application.create_referrer_filter('1.2.3.4')
      assert !Referrer.apply(@status, :referrer => "1.2.3.4\n")
    end

    test 'apply fails if the referrer includes URI parts and the filter is just a host' do
      @application.create_referrer_filter('example.com')

      assert !Referrer.apply(@status, :referrer => 'http://example.com')
      assert !Referrer.apply(@status, :referrer => 'example.com:80')
      assert !Referrer.apply(@status, :referrer => 'example.com/some/path')
      assert !Referrer.apply(@status, :referrer => 'example.com/path?param=value')
    end
  end
end
