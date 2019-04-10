require 'rspec'
require 'resque_spec'
require 'async'

if ENV['TEST_COVERAGE']
  require 'simplecov'

  if ENV['CODECLIMATE_REPO_TOKEN']
    require 'codeclimate-test-reporter'

    # Monkey-patching CodeClimate.
    module CodeClimate
      module TestReporter
        class PayloadValidator
          # The original method just checks the first term of the OR.
          # @payload[:git] is populated using git commands, which we cannot use
          # in Jenkins as we have .git in the .dockerignore file to avoid
          # including it in the production images.
          def committed_at
            (@payload[:git] && @payload[:git][:committed_at]) ||
                ENV['GIT_TIMESTAMP'].to_i
          end
        end
      end
    end

    SimpleCov.at_exit do
      CodeClimate::TestReporter::Formatter.new.format(SimpleCov.result)
    end
  end
end

require_relative '../lib/3scale/backend.rb'
require_relative '../test/test_helpers/sequences.rb'

RSpec.configure do |config|
  config.before :suite do
    require_relative '../test/test_helpers/configuration'
    require_relative '../test/test_helpers/storage'

    TestHelpers::Storage::Mock.mock_storage_clients
  end

  config.after :suite do
    TestHelpers::Storage::Mock.unmock_storage_clients
  end

  config.mock_with :rspec

  config.before :each do
    ThreeScale::Backend::Storage.instance(true).flushdb
    ThreeScale::Backend::Memoizer.reset!
  end

  config.after :each do
    ThreeScale::Backend::Storage.instance.close
  end

  config.around :each do |example|
    Async.run do
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
