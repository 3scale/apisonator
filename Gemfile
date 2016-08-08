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
  gem 'pry-byebug', '~> 3.4.0', groups: [:development]
end

group :test do
  gem 'mocha',       '~> 1.1.0'
  gem 'nokogiri',    '~> 1.6.7'
  gem 'rack-test',   '~> 0.6.2'
  gem 'resque_unit', '~> 0.4.4', source: 'https://rubygems.org'
  gem 'test-unit',   '= 3.2.1'
  gem 'resque_spec', '~> 0.17.0'
  gem 'timecop',     '~> 0.8.0'
  gem 'rspec',       '~> 3.5.0', require: nil
  gem 'codeclimate-test-reporter', '~> 0.6.0', require: nil
  gem 'geminabox', require: false
end

group :development do
  gem 'sshkit'
  gem 'source2swagger', github: 'unleashed/source2swagger', branch: 'master'
  gem 'pry',      '~> 0.10.4'
  gem 'pry-doc',  '~> 0.9.0'
end

group :development, :test do
  gem 'rspec_api_documentation', '~> 4.8.0'
end

# Default server by platform
gem 'puma', '= 2.15.3'
# gems required by the runner
gem 'gli', '~> 2.14.0', require: nil
# Cubert client
gem 'cubert-client', '= 0.0.12', source: 'https://geminabox'
# Workers
gem 'daemons', '= 1.1.9'

# Production gems
gem 'rake', '= 10.4.2'
gem 'builder', '= 3.2.2'
gem 'hiredis', '= 0.6.1'
gem 'redis', '= 3.2.2'
gem 'redis-namespace', '= 1.5.2'
gem 'resque', '= 1.23.0'
gem 'rack', '= 1.6.4'
gem 'airbrake', '= 4.3.0'
gem 'tilt', '= 1.4.1'
gem 'sinatra', '= 1.4.7'
gem 'sinatra-contrib', '= 1.4.7'
gem 'aws-sdk', '= 2.4.2'
gem 'whenever', '= 0.9.7'
gem 'pg', '= 0.18.4'
gem 'scientist', '= 1.0.0'
gem 'statsd-ruby', '= 1.3.0'
