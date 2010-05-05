require File.dirname(__FILE__) + '/../test_helper'

class ConfigurationTest < Test::Unit::TestCase
  def setup
    @original_env = ENV['RAILS_ENV']
  end

  def teardown
    ENV['RAILS_ENV'] = @original_env
  end

  def test_configuration_is_environment_specific
    FakeFS do
      config = {'development' => {'foo' => true},
                'test'        => {'foo' => false}}
      File.open('config.yml', 'w') do |io|
        YAML.dump(config, io)
      end

      ENV['RACK_ENV'] = 'test'
      configuration = Configuration.new('config.yml')
      assert_equal false, configuration.foo

      ENV['RACK_ENV'] = 'development'
      configuration = Configuration.new('config.yml')
      assert_equal true, configuration.foo
    end
  end

end
