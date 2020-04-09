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

      @status = Transactor::Status.new(service_id: @service.id,
                                       application: @application)
    end

    def run_new_and_legacy(&blk)
      [true, false].each do |legacy|
        Referrer.behave_as_legacy legacy
        blk.call
      end
    end


    ## COMMON BEHAVIOR NEW AND LEGACY VERSION

    test 'succeeds if no referrer filter is defined and no referrer is passed' do
      run_new_and_legacy { assert Referrer.apply(@status, {}) }
    end

    test 'succeeds if no referrer filter is defined and blank referrer is passed' do
      run_new_and_legacy { assert Referrer.apply(@status, :referrer => '') }
    end

    test 'succeeds if simple domain filter is defined and matching referrer is passed' do
      run_new_and_legacy do
        @application.create_referrer_filter('example.org')
        assert Referrer.apply(@status, :referrer => 'example.org')
      end
    end

    test 'succeeds if wildcard filter is defined and matching referrer is passed' do
      run_new_and_legacy do
        @application.create_referrer_filter('*.example.org')

        assert Referrer.apply(@status, :referrer => 'foo.example.org')
        assert Referrer.apply(@status, :referrer => 'bar.example.org')
        assert Referrer.apply(@status, :referrer => 'foo.bar.example.org')
      end
    end

    test 'succeeds if simple ip filter is defined and matching referrer is passed' do
      run_new_and_legacy do
        @application.create_referrer_filter('127.0.0.1')
        assert Referrer.apply(@status, :referrer => '127.0.0.1')
      end
    end

    test 'succeeds if a referrer filter is defined and bypass string is passed' do
      run_new_and_legacy do
        @application.create_referrer_filter('example.org')
        assert Referrer.apply(@status, :referrer => '*')
      end
    end

    test 'fails if referrer filter is defined but no referrer is passed' do
      run_new_and_legacy do
        @application.create_referrer_filter('example.org')

        assert !Referrer.apply(@status, {})

        assert_equal 'referrer_not_allowed', @status.rejection_reason_code
        assert_equal 'referrer is missing',  @status.rejection_reason_text
      end
    end

    test 'fails if simple domain filter is defined but non-matching referrer is passed' do
      run_new_and_legacy do
        @application.create_referrer_filter('foo.example.org')

        assert !Referrer.apply(@status, :referrer => 'bar.example.org')
        assert_equal 'referrer_not_allowed',                      @status.rejection_reason_code
        assert_equal 'referrer "bar.example.org" is not allowed', @status.rejection_reason_text
      end
    end

    test 'fails if wildcard filter is defined but non-matching referrer is passed' do
      run_new_and_legacy do
        @application.create_referrer_filter('*.example.org')

        assert !Referrer.apply(@status, :referrer => 'foo.example.com')
        assert !Referrer.apply(@status, :referrer => 'example.org')
      end
    end

    test 'fails if simple ip filter is defined but non-matching referrer is passed' do
      run_new_and_legacy do
        @application.create_referrer_filter('127.0.0.1')
        assert !Referrer.apply(@status, :referrer => '127.0.0.2')
      end
    end

    test 'dot in a filter matches only dot' do
      run_new_and_legacy do
        @application.create_referrer_filter('fo.example.org')
        assert !Referrer.apply(@status, :referrer => 'forexample.org')
      end
    end

    test 'succeeds when service does not require referrer filters' do
      run_new_and_legacy do
        service_no_filters = Service.save!(:provider_key => 'a_provider_key',
                                           :id => next_id,
                                           :referrer_filters_required => false)

        app = Application.save(:service_id => service_no_filters.id,
                               :id => next_id,
                               :state => :active)

        status = Transactor::Status.new(service_id: service_no_filters.id,
                                        application: app)

        app.create_referrer_filter('accepted.org')

        assert Referrer.apply(status, :referrer => 'unaccepted.org')
      end
    end

    # TODO: maybe filters like the ones in the following tests should not even be allowed.

    test 'filter is not a regular expression' do
      run_new_and_legacy do
        @application.create_referrer_filter('ba[rz].example.org')

        assert !Referrer.apply(@status, :referrer => 'bar.example.org')
        assert !Referrer.apply(@status, :referrer => 'baz.example.org')
        assert  Referrer.apply(@status, :referrer => 'ba[rz].example.org')
      end
    end

    test 'filter works if it looks like a broken regular expression' do
      run_new_and_legacy do
        @application.create_referrer_filter('(example.org')

        assert Referrer.apply(@status, :referrer => '(example.org')
      end
    end

    test 'filters can be used for ignoring parts of the URI (scheme, path, etc.)' do
      run_new_and_legacy do
        @application.create_referrer_filter('*://example.com')
        @application.create_referrer_filter('http://8.8.8.8/*')

        assert Referrer.apply(@status, :referrer => 'http://example.com')
        assert Referrer.apply(@status, :referrer => 'https://example.com')
        assert !Referrer.apply(@status, :referrer => 'example.com')

        assert Referrer.apply(@status, :referrer => 'http://8.8.8.8/some/path')
        assert Referrer.apply(@status, :referrer => 'http://8.8.8.8/path?qs=value')
      end
    end

    # this mostly is for documentation purposes but also to notice changes in
    # semantics.
    test 'filter works in edge cases even though we would want to fix em some day' do
      run_new_and_legacy do
        @application.create_referrer_filter('194.179.*.10')
        @application.create_referrer_filter('8.8.8.*')
        @application.create_referrer_filter('*.3scale.net')

        assert Referrer.apply(@status, :referrer => '194.179..10')
        assert Referrer.apply(@status, :referrer => '194.179.something.10')
        assert Referrer.apply(@status, :referrer => '194.179.10.10.10.10')
        assert Referrer.apply(@status, :referrer => '194.179.999.10')

        assert Referrer.apply(@status, :referrer => '8.8.8.amazon-aws.com')
        assert Referrer.apply(@status, :referrer => '8.8.8.8:443')
        assert Referrer.apply(@status, :referrer => '8.8.8.8/some/path?qs=lol')

        assert Referrer.apply(@status, :referrer => '.3scale.net')
        assert Referrer.apply(@status, :referrer => 'https://something.3scale.net')
      end
    end


    ## LEGACY

    test 'succeeds if the referrer matches the filter but with extra chars at the beginning' do
      Referrer.behave_as_legacy true
      @application.create_referrer_filter('1.2.3.4')
      assert Referrer.apply(@status, :referrer => '231.2.3.4')
    end

    test 'succeeds if the referrer matches the filter but with extra chars at the end' do
      Referrer.behave_as_legacy true
      @application.create_referrer_filter('1.2.3.4')
      assert Referrer.apply(@status, :referrer => '1.2.3.456')
    end

    test 'succeeds if the referrer matches the filter but with an extra \n' do
      Referrer.behave_as_legacy true
      @application.create_referrer_filter('1.2.3.4')
      assert Referrer.apply(@status, :referrer => "1.2.3.4\n")
    end

    # Note: this is because of the implicit '*' that are inserted at the
    # beginning and the end of the filter.
    test 'succeeds if the referrer includes a scheme, path, etc. when the filter is a host' do
      Referrer.behave_as_legacy true
      @application.create_referrer_filter('example.com')

      assert Referrer.apply(@status, :referrer => 'http://example.com')
      assert Referrer.apply(@status, :referrer => 'example.com:80')
      assert Referrer.apply(@status, :referrer => 'example.com/some/path')
      assert Referrer.apply(@status, :referrer => 'example.com/path?param=value')
    end


    ## NEW VERSION

    test 'fails if the referrer matches the filter but with extra chars at the beginning' do
      Referrer.behave_as_legacy false
      @application.create_referrer_filter('1.2.3.4')
      assert !Referrer.apply(@status, :referrer => '231.2.3.4')
    end

    test 'fails if the referrer matches the filter but with extra chars at the end' do
      Referrer.behave_as_legacy false
      @application.create_referrer_filter('1.2.3.4')
      assert !Referrer.apply(@status, :referrer => '1.2.3.456')
    end

    test 'fails if the referrer matches the filter but with an extra \n' do
      Referrer.behave_as_legacy false
      @application.create_referrer_filter('1.2.3.4')
      assert !Referrer.apply(@status, :referrer => "1.2.3.4\n")
    end

    test 'fails if the referrer includes URI parts and the filter is just a host' do
      Referrer.behave_as_legacy false
      @application.create_referrer_filter('example.com')

      assert !Referrer.apply(@status, :referrer => 'http://example.com')
      assert !Referrer.apply(@status, :referrer => 'example.com:80')
      assert !Referrer.apply(@status, :referrer => 'example.com/some/path')
      assert !Referrer.apply(@status, :referrer => 'example.com/path?param=value')
    end

  end
end
