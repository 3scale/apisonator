require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class ErrorReporterTest < Test::Unit::TestCase
  include TestHelpers::Sequences

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb
    
    @service_id = next_id
  end

  def test_report_pushes_error_to_the_storage
    Timecop.freeze(Time.utc(2010, 7, 29, 15, 10)) do
      ErrorReporter.report(@service_id, ApplicationNotFound.new('boo'))
    end

    raw_error = @storage.lpop("errors/service_id:#{@service_id}")

    assert_not_nil raw_error

    error = Yajl::Parser.parse(raw_error)

    assert_equal 'application_not_found',                   error['code']
    assert_equal 'application with id="boo" was not found', error['message']
    assert_equal '2010-07-29 15:10:00 UTC',                 error['timestamp']
  end

  def test_all_returns_collection_of_errors
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

    assert_equal expected, ErrorReporter.all(@service_id)
  end

  def test_all_returns_empty_collection_if_there_are_no_errors
    assert_equal [], ErrorReporter.all(@service_id)
  end

  def test_reported_error_is_in_the_collection_of_errors
    Timecop.freeze(Time.utc(2010, 7, 29, 15, 59)) do
      ErrorReporter.report(@service_id, ApplicationNotFound.new('boo'))
    end

    assert_equal({:code      => 'application_not_found',
                  :message   => 'application with id="boo" was not found',
                  :timestamp => Time.utc(2010, 7, 29, 15, 59)},
                 ErrorReporter.all(@service_id).last)
  end
end
