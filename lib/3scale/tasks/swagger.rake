def run_command cmd
  puts "--> executing: #{cmd}"
  system cmd
end

def endpoint_file(type)
  res = 'docs/active_docs/endpoint'
  res << '_onprem' if type == :on_prem
  res
end

# The file name depends on the 'namespace' defined in the Listener.
def spec_file(type)
  res = 'docs/active_docs/Service Management API'
  res << ' (on-premises)' if type == :on_prem
  "#{res}.json"
end

def generate_docs(type)
  spec = spec_file(type)
  cmd = type == :saas ? 'SAAS_SWAGGER=1' : 'SAAS_SWAGGER=0'
  cmd << ' bundle exec source2swagger -f lib/3scale/backend/listener.rb -c "##~" -o docs/active_docs/.'
  run_command cmd
  # source2swagger is really bad at generating readable JSON
  require 'json'
  File.write(spec, JSON.pretty_generate(JSON.parse(File.read(spec))) << "\n")
end

def upload_docs(type)
  require 'uri' unless Kernel.const_defined? :URI
  endpoint = URI.encode(
      File.readlines(endpoint_file(type)).find do |line|
        line !~ /\A\s*(#.*)?\n?\z/
      end.chomp)
  run_command "curl -v -X PUT -F \"body=@#{spec_file(type)}\" \"#{endpoint}\""
end

namespace :docs do
  namespace :swagger do
    desc "Generates and uploads all swagger docs"
    task all: ["generate:all", "upload:all"]

    namespace :generate do
      desc "Generates all swagger docs"
      task all: [:saas, :on_prem]

      desc "Generates swagger docs for SaaS"
      task :saas do
        generate_docs(:saas)
      end

      desc "Generates swagger docs for on-prem"
      task :on_prem do
        generate_docs(:on_prem)
      end
    end

    namespace :upload do
      desc "Uploads all swagger docs"
      task all: [:saas, :on_prem]

      desc "Uploads swagger docs for SaaS"
      task :saas do
        upload_docs(:saas)
      end

      desc "Uploads swagger docs for on-prem"
      task :on_prem do
        upload_docs(:on_prem)
      end
    end
  end
end
