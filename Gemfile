source 'https://rubygems.org'
gemspec
gem 'require_all', '~> 1.2.1'
gem 'rake',        '~> 10.0.3'
gem '3scale_core', require: '3scale/core', git: 'git@github.com:3scale/core.git', tag: '0.7.0'

group :test do
  gem 'fakefs',      '~> 0.4.2'
  gem 'mocha',       '~> 0.13.2'
  gem 'nokogiri',    '~> 1.5.6'
  gem 'rack-test',   '~> 0.6.2'
  gem 'resque_unit', '~> 0.4.4'
  gem 'timecop',     '~> 0.5.9.2'
  gem 'codeclimate-test-reporter', '~> 0.3.0', require: nil
end

group :development do
  gem 'capistrano',  '~> 2.14.2'
end

group :development, :test do
  gem 'debugger', '~> 1.6.5'
  gem 'pry',      '~> 0.9.12.6'
  gem 'pry-doc',  '~> 0.5.1'
  gem 'rspec_api_documentation', '~> 2.0.0'
end
