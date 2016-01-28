source 'https://rubygems.org'

gemspec

# C-API only gems
#
# It is useful to tag these because not all Ruby implementations support these
# kinds of gems. In particular, gems here have NO alternative non C-API
# implementations (ie. pure Ruby, java, etc).
#
platform :ruby do
  gem 'yajl-ruby', '= 1.1.0'
  gem 'pry-byebug', '~> 3.2.0', groups: [:development, :test]
end

# Default server by platform
gem 'puma', '= 2.15.3'

platform :mri do
  gem 'thin', '= 1.6.3', groups: [:development, :test]
end

group :test do
  gem 'mocha',       '~> 1.1.0'
  gem 'nokogiri',    '~> 1.6.2'
  gem 'rack-test',   '~> 0.6.2'
  gem 'resque_unit', '~> 0.4.4'
  gem 'resque_spec', '~> 0.17.0'
  gem 'timecop',     '~> 0.7.1'
  gem 'rspec',       '~> 3.4.0', require: nil
  gem 'codeclimate-test-reporter', '~> 0.3.0', require: nil
  gem 'geminabox', require: false
end

group :development do
  gem 'sshkit'
  gem 'source2swagger', github: 'unleashed/source2swagger', branch: 'master'
end

group :development, :test do
  gem 'pry',      '~> 0.10.1'
  gem 'pry-doc',  '~> 0.8.0'
  gem 'rspec_api_documentation', '~> 4.6.0'
end

# gems required by the runner
gem 'gli', '~> 2.13.2', require: nil
