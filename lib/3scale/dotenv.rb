# Ensure the proper .env file is loaded
#
# Don't load any .env file for production
# First, try to load `.env.#{ENV['RACK_ENV']}`
# If doesn't exist, try to load .env.test
# If doesn't exist, try to load .env
def env_file
  file = ".env.#{ENV['RACK_ENV']}"
  return file if File.exists?(file)

  File.exists?('.env.test') ? '.env.test' : '.env'
end

begin
  return if ENV['RACK_ENV'] == 'production'

  require 'dotenv'

  Dotenv.load env_file
end
