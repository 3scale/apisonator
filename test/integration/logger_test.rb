require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class LoggerTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Rack::Builder.new {
      use ThreeScale::Backend::Logger::Middleware
      run ThreeScale::Backend::Listener.new
    }.to_app
  end

  def default_log_writer
    ThreeScale::Backend::Logger::Middleware::TextWriter
  end

  test 'log valid requests with request info and stats info' do
    default_log_writer.any_instance.expects(:log).once

    assert_nothing_raised do
      post '/transactions.xml?transactions[0]=foo2', provider_key: 'foo'
    end
  end

  test 'log failed requests with request info and error info' do
    redis = Backend::Storage.any_instance
    redis.expects(:get).raises(TimeoutError)

    default_log_writer.any_instance.expects(:log_error).once

    assert_raise TimeoutError do
      post '/transactions.xml?transactions[0]=foo2', provider_key: 'foo'
    end
  end
end
