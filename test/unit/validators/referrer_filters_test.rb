require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

module Validators
  class ReferrerFiltersTest < Test::Unit::TestCase
    include TestHelpers::Sequences
    include Validators

    def setup
      Storage.instance(true).flushdb

      @service     = Service.save(:provider_key => 'foobar', :id => next_id)
      @application = Application.save(:service_id => @service.id,
                                      :id         => next_id,
                                      :state => :active)

      @status = Transactor::Status.new(@service, @application, {})
    end

    test 'succeeds when referrer filters are not required' do
      @service.referrer_filters_required = false
      @service.save

      assert ReferrerFilters.apply(@status, {})
    end

    test 'succeeds when referrer filters are required and defined' do
      @service.referrer_filters_required = true
      @service.save

      @application.create_referrer_filter('foo.example.org')

      assert ReferrerFilters.apply(@status, {})
    end

    test 'fails when referrer filters are required but not defined' do
      @service.referrer_filters_required = true

      assert !ReferrerFilters.apply(@status, {})
      assert_equal 'referrer_filters_missing',     @status.rejection_reason_code
      assert_equal 'referrer filters are missing', @status.rejection_reason_text
    end
  end
end
