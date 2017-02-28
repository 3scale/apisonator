# This extension is a hack to allow gem install to take Gemfile into account.
#
require 'rubygems'
require 'pathname'

BUNDLER_GEM = 'bundler'

def bundled_with(lockfile)
  File.read(lockfile).
    lines.each_cons(2).find do |f, _|
      f == "BUNDLED WITH\n".freeze
    end.last.strip
end

def bundler_requirements(version, reqtype = '=')
  ["#{reqtype} #{version}"]
end

def gem_install_bundler(requirements)
  require 'rubygems/command'
  require 'rubygems/commands/install_command'
  begin
    Gem::Command.build_args = ARGV
  rescue NoMethodError
  end

  instcmd = Gem::Commands::InstallCommand.new
  instcmd.handle_options ['-N', BUNDLER_GEM, '--version', *requirements]
  begin
    instcmd.execute
  rescue Gem::SystemExitException => e
    raise e unless e.exit_code.zero?
  end
end

def get_bundler(requirements)
  Gem::Specification.find_by_name(BUNDLER_GEM, *requirements)
end

begin
  extdir = Pathname.new(__FILE__).dirname.realpath
  rootdir = File.expand_path('..', extdir)
  gemfile = File.join rootdir, 'Gemfile'
  bundled_with_version = bundled_with(gemfile + '.lock')
  bundler_reqs = bundler_requirements bundled_with_version
  gem_install_bundler bundler_reqs
  bundler = get_bundler bundler_reqs
  bundler_version = bundler.version
  raise "installed bundler version #{bundler_version} must match required " \
    "version #{bundled_with_version}" if bundled_with_version != bundler_version.version
  bundle_bin = bundler.bin_file 'bundle'
  IO.popen(%W{#{Gem.ruby} #{bundle_bin} install --without development test --gemfile=#{gemfile}}) do |io|
    STDOUT.puts "Running bundler #{bundler_version} at #{bundle_bin} from #{Dir.pwd} with pid #{io.pid}"
    io.each_line { |l| puts l }
  end
  raise "bundle install failed: #{$?.inspect}" unless $?.success?
  # create dummy rakefile to indicate success
  File.open(File.join(extdir, 'Rakefile'), 'w') do |f|
    f.write("task :default\n")
  end
rescue => e
  STDERR.puts "Error: #{e.message} - #{e.class}"
  exit 1
end
