def run_command cmd
  puts "--> executing: #{cmd}"
  system cmd
end

def endpoint_file(type)
  res = 'docs/active_docs/endpoint'
  res << '_onprem' if type == :on_prem
  res
end

def active_docs_host
  'active_docs_host'.freeze
end

def support_account_endpoint(service_id, provider_key)
  "https://#{active_docs_host}/admin/api/active_docs/"\
  "#{service_id}.xml?provider_key=#{provider_key}"
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

def upload_docs(type, service_id, provider_key)
  require 'uri' unless Kernel.const_defined? :URI
  endpoint = URI.encode(support_account_endpoint(service_id, provider_key))
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
        service_id = ENV['SWAGGER_SAAS_SERVICE_ID']
        provider_key = ENV['SWAGGER_PROVIDER_KEY']
        if service_id.nil? || provider_key.nil?
          raise 'Please set SWAGGER_SAAS_SERVICE_ID and SWAGGER_PROVIDER_KEY'
        end

        upload_docs(:saas, service_id, provider_key)
      end

      desc "Uploads swagger docs for on-prem"
      task :on_prem do
        service_id = ENV['SWAGGER_ONPREM_SERVICE_ID']
        provider_key = ENV['SWAGGER_PROVIDER_KEY']
        if service_id.nil? || provider_key.nil?
          raise 'Please set SWAGGER_ONPREM_SERVICE_ID and SWAGGER_PROVIDER_KEY'
        end

        upload_docs(:on_prem, service_id, provider_key)
      end
    end
  end
end
