# Ensure the proper .env file is loaded
#
# Don't load any .env file for production or staging
# First, try to load `.env.#{ENV['RACK_ENV']}`
# If doesn't exist, try to load .env.test
def env_file
  file = ".env.#{ENV['RACK_ENV']}"
  File.exist?(file) ? file : '.env.test'
end

begin
  return if %w(staging production).include?(ENV['RACK_ENV'])

  require 'dotenv'

  Dotenv.load env_file
end
