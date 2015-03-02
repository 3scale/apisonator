source 'https://rubygems.org'

gemspec

group :test do
  gem 'mocha',       '~> 0.13.2'
  gem 'nokogiri',    '~> 1.6.2'
  gem 'rack-test',   '~> 0.6.2'
  gem 'resque_unit', '~> 0.4.4'
  gem 'resque_spec', '~> 0.15.0'
  gem 'timecop',     '~> 0.7.1'
  gem 'codeclimate-test-reporter', '~> 0.3.0', require: nil
  gem 'geminabox', require: false
  gem 'ci_reporter_test_unit', require: nil
  gem 'ci_reporter_rspec', require: nil
end

group :development, :test do
  gem 'pry',      '~> 0.10.0'
  gem 'pry-doc',  '~> 0.6.0'
  gem 'pry-byebug', '~> 2.0.0'
  gem 'rspec_api_documentation', '~> 2.0.0'
end

gem 'sshkit', group: :development
