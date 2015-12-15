require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class ErrorStorageTest < Test::Unit::TestCase
  include TestHelpers::Sequences

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb

    @service_id = next_id
  end

 test '#store pushes error to the storage' do
    Timecop.freeze(Time.utc(2010, 7, 29, 15, 10)) do
      ErrorStorage.store(@service_id, ApplicationNotFound.new('boo'))
    end

    raw_error = @storage.lpop("errors/service_id:#{@service_id}")

    assert_not_nil raw_error

    error = Yajl::Parser.parse(raw_error)

    assert_equal 'application_not_found',                   error['code']
    assert_equal 'application with id="boo" was not found', error['message']
    assert_equal '2010-07-29 15:10:00 UTC',                 error['timestamp']
  end

  test '#list returns errors from the storage' do
    @storage.rpush("errors/service_id:#{@service_id}",
                   Yajl::Encoder.encode(:code      => 'application_not_found',
                                        :message   => 'application with id="foo" was not found',
                                        :timestamp => '2010-07-29 15:23:00 UTC'))

    @storage.rpush("errors/service_id:#{@service_id}",
                   Yajl::Encoder.encode(:code      => 'metric_invalid',
                                        :message   => 'metric "bars" is invalid',
                                        :timestamp => '2010-07-29 15:44:00 UTC'))

    expected = [{:code      => 'application_not_found',
                 :message   => 'application with id="foo" was not found',
                 :timestamp => Time.utc(2010, 7, 29, 15, 23)},
                {:code      => 'metric_invalid',
                 :message   => 'metric "bars" is invalid',
                 :timestamp => Time.utc(2010, 7, 29, 15, 44)}]

    assert_equal expected, ErrorStorage.list(@service_id)
  end

  test '#list stores max of MAX_NUM_ERRORS' do
    (ErrorStorage::MAX_NUM_ERRORS+10).times do |i|
      ErrorStorage.store(@service_id, ApplicationNotFound.new("boo_#{i}"))
    end

    list = ErrorStorage.list(@service_id, {:page =>1, :per_page => ErrorStorage::MAX_NUM_ERRORS*2})
    assert_equal ErrorStorage::MAX_NUM_ERRORS, list.size
    assert_equal "application with id=\"boo_#{ErrorStorage::MAX_NUM_ERRORS+10-1}\" was not found", list.first[:message]
    assert_equal 'application with id="boo_10" was not found', list.last[:message]
  end

  test '#list returns empty collection if there are no errors' do
    assert_equal [], ErrorStorage.list(@service_id)
  end

  test '#list paginates the collection' do
    start_time = Time.utc(2010, 9, 9, 10, 00)

    # Generate 5 errors, every minute one:
    #  - 5: 2010-09-09 10:00
    #  - 4: 2010-09-09 10:01
    #  - 3: 2010-09-09 10:02
    #  - 2: 2010-09-09 10:03
    #  - 1: 2010-09-09 10:04
    5.times do |index|
      Timecop.freeze(start_time + index * 60) do
        ErrorStorage.store(@service_id, MetricInvalid.new('foo'))
      end
    end

    errors = ErrorStorage.list(@service_id, :page => 2, :per_page => 2)

    assert_equal 2, errors.size
    assert_equal Time.utc(2010, 9, 9, 10, 2), errors[0][:timestamp]
    assert_equal Time.utc(2010, 9, 9, 10, 1), errors[1][:timestamp]
  end

  test '#list handles the last page' do
    start_time = Time.utc(2010, 9, 9, 10, 00)

    #  - 3: 2010-09-09 10:00
    #  - 2: 2010-09-09 10:01
    #  - 1: 2010-09-09 10:02
    3.times do |index|
      Timecop.freeze(start_time + index * 60) do
        ErrorStorage.store(@service_id, MetricInvalid.new('foo'))
      end
    end

    errors = ErrorStorage.list(@service_id, :page => 2, :per_page => 2)

    assert_equal 1, errors.size
    assert_equal Time.utc(2010, 9, 9, 10, 0), errors[0][:timestamp]
  end

  test '#count return 0 if there are no errors' do
    assert_equal 0, ErrorStorage.count(@service_id)
  end

  test '#count returns number of errors' do
    3.times { ErrorStorage.store(@service_id, MetricInvalid.new('boo')) }

    assert_equal 3, ErrorStorage.count(@service_id)
  end

  test '#count does not include errors of other services' do
    other_service_id = next_id
    ErrorStorage.store(other_service_id, ApplicationNotFound.new('foo'))
    ErrorStorage.store(@service_id,      ApplicationNotFound.new('bar'))

    assert_equal 1, ErrorStorage.count(@service_id)
  end

  test '#delete_all deletes all errors from the storage' do
    @storage.rpush("errors/service_id:#{@service_id}",
                   Yajl::Encoder.encode(:code      => 'application_not_found',
                                        :message   => 'application with id="foo" was not found',
                                        :timestamp => '2010-09-03 17:15:00 UTC'))

    ErrorStorage.delete_all(@service_id)

    values = @storage.lrange("errors/service_id:#{@service_id}", 0, -1)

    # Some redis versions return nil, some empty array. I care only that it
    # does not contain any stuff.
    assert values.nil? || values.empty?
  end

  test '#delete_all does not deletes errors of other services' do
    other_service_id = next_id
    ErrorStorage.store(other_service_id, ApplicationNotFound.new('foo'))
    ErrorStorage.delete_all(@service_id)

    assert_equal 1, ErrorStorage.list(other_service_id).size
  end

  # Semi-integration tests:

  test 'list returns previously stored errors' do
    Timecop.freeze(Time.utc(2010, 7, 29, 15, 59)) do
      ErrorStorage.store(@service_id, ApplicationNotFound.new('boo'))
    end

    assert_equal({:code         => 'application_not_found',
                  :context_info => {},
                  :message      => 'application with id="boo" was not found',
                  :timestamp    => Time.utc(2010, 7, 29, 15, 59)},
                 ErrorStorage.list(@service_id).last)
  end

  test 'list returns the errors in reverse-insertion order' do
    ErrorStorage.store(@service_id, MetricInvalid.new('foo'))
    ErrorStorage.store(@service_id, UsageValueInvalid.new('hits', 'lots'))

    errors = ErrorStorage.list(@service_id)
    assert_equal 'usage_value_invalid', errors[0][:code]
    assert_equal 'metric_invalid',      errors[1][:code]
  end

  test 'list is empty after #delete_all' do
    ErrorStorage.store(@service_id, ApplicationNotFound.new('boo'))
    ErrorStorage.delete_all(@service_id)

    assert_equal [], ErrorStorage.list(@service_id)
  end
end
