require 'rspec'
require 'resque_spec'

if ENV['TEST_COVERAGE']
  require 'simplecov'

  if ENV['CODECLIMATE_REPO_TOKEN']
    require 'codeclimate-test-reporter'
    SimpleCov.at_exit do
      CodeClimate::TestReporter::Formatter.new.format(SimpleCov.result)
    end
  end
end

require_relative '../lib/3scale/backend.rb'
require_relative '../test/test_helpers/sequences.rb'

RSpec.configure do |config|
  config.before :suite do
    ThreeScale::Backend.configure do |app_config|
      app_config.redis.nodes = [
        "127.0.0.1:7379",
        "127.0.0.1:7380",
      ]

      app_config.cubert.host = 'http://localhost:8080'

      app_config.redshift.host = 'localhost'
      app_config.redshift.port = 5432
      app_config.redshift.dbname = 'test'
      app_config.redshift.user = 'postgres'
    end
  end

  config.mock_with :rspec

  config.before :each do
    ThreeScale::Backend::Storage.instance(true).flushdb
    ThreeScale::Backend::Memoizer.reset!
  end
end

# Converts the full name of an exception like
# ThreeScale::Backend::InvalidProviderKeys to InvalidProviderKeys
def formatted_name(exception)
  exception.name.split(':').last
end

# Require spec helpers
Dir[File.dirname(__FILE__) + '/spec_helpers/**/*.rb'].each { |file| require file }
