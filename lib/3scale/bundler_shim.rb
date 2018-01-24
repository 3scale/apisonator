# Setup bundler if present before anything else.
#
# We are not guaranteed to be running in a Bundler context, so make sure we get
# the correct environment set up to require the correct code.
begin
  require 'bundler/setup'
  if !Bundler::SharedHelpers.in_bundle?
    # Gemfile not found, try with relative Gemfile from us
    require 'pathname'
    ENV['BUNDLE_GEMFILE'] = File.expand_path(File.join('..', '..', '..', 'Gemfile'),
                                             Pathname.new(__FILE__).realpath)
    require 'bundler'
    Bundler.setup
  end
rescue LoadError, Bundler::BundlerError => e
  STDERR.puts "CRITICAL: Bundler could not be loaded properly - #{e.message}"
end
