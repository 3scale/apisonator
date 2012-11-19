# encoding: UTF-8
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
 
require '3scale/backend/version'
 
Gem::Specification.new do |s|
  s.name        = '3scale_backend'
  s.version     = ThreeScale::Backend::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Adam Cigánek", "Tiago Macedo","Josep M. Pujol"]
  s.email       = 'tiago@3scale.net'
  s.homepage    = 'http://www.3scale.net'
  s.summary     = '3scale web service management system backend'
  s.description = 'This gem provides a daemon that handles authorization and reporting of web services managed by 3scale.'
 
  s.required_rubygems_version = ">= 1.3.7"
    
  s.add_dependency '3scale_core',               '~> 0.5.0'
  s.add_dependency 'aws-s3',                    '0.6.3'
  s.add_dependency 'builder',                   '2.1.2'
  s.add_dependency 'hiredis',                   '0.4.5'
  s.add_dependency 'redis',                     '3.0.2'
  s.add_dependency 'resque',                    '1.23.0' # please use this in production/staging -> https://github.com/tmacedo/resque
  s.add_dependency 'rack',                      '1.4.1'
  s.add_dependency 'rack-rest_api_versioning',  '0.0.2'
  s.add_dependency 'airbrake',                  '3.1.6'
  s.add_dependency 'sinatra',                   '1.2.8'
  s.add_dependency 'thin',                      '1.5.0'
  s.add_dependency 'yajl-ruby',                 '0.8.3'
  s.add_dependency 'cassandra-cql',             '1.0.4'
  s.add_dependency 'rest-client',               '1.6.7'
  s.add_dependency 'redis-namespace',           '1.2.1'
  
  
  s.add_development_dependency 'fakefs',      '~> 0.3.0'
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'nokogiri'
  s.add_development_dependency 'rack-test'
  s.add_development_dependency 'resque_unit', '0.2.7'
  s.add_development_dependency 'timecop'
  s.add_development_dependency 'simplecov', '~> 0.4.0'
 
  s.files = Dir.glob('{lib,bin}/**/*')
  s.files << 'README.rdoc'
  s.files << 'Rakefile'

  s.executables  = ['3scale_backend', '3scale_backend_worker']
  s.require_path = 'lib'
end
