require 'rspec'
require 'resque_spec'
require 'async'

require 'active_support'
require 'active_support/core_ext/object/json'
require 'active_support/core_ext/hash/keys'

if ENV['TEST_COVERAGE']
  require 'simplecov'
end

require_relative '../lib/3scale/backend.rb'
require_relative '../lib/3scale/backend/job_fetcher'
require_relative '../test/test_helpers/sequences.rb'

RSpec.configure do |config|
  config.before :suite do
    require_relative '../test/test_helpers/configuration'
    require_relative '../test/test_helpers/storage'

    TestHelpers::Storage::Mock.mock_storage_clients

    # Initialize the worker logger for those cases that worker is called without creating a worker first.
    # Only happens in test environment
    ThreeScale::Backend::Logging::Worker.configure_logging(ThreeScale::Backend::Worker, '/dev/null')
  end

  config.after :suite do
    TestHelpers::Storage::Mock.unmock_storage_clients
  end

  config.mock_with :rspec

  config.before :each do
    Resque::Failure.clear
    ThreeScale::Backend::JobFetcher.const_get(:QUEUES).each { |queue| Resque.remove_queue(queue) }
    ThreeScale::Backend::Storage.instance(true).flushdb
    ThreeScale::Backend::Memoizer.reset!
  end

  config.after :each do
    ThreeScale::Backend::Storage.instance.close
  end

  config.around :each do |example|
    Sync do
      # TODO: This is needed for the acceptance specs. Not sure why.
      RSpec.current_example = example

      example.run
    end
  end
end

# Converts the full name of an exception like
# ThreeScale::Backend::InvalidProviderKeys to InvalidProviderKeys
def formatted_name(exception)
  exception.name.split(':').last
end

# Require spec helpers
Dir[File.dirname(__FILE__) + '/spec_helpers/**/*.rb'].each { |file| require file }
