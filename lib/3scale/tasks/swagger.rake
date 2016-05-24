def run_command cmd
  puts "--> executing: #{cmd}"
  system cmd
end

namespace :docs do
  namespace :swagger do
    desc "Generates and uploads all swagger docs"
    task all: ["generate:all", "upload:all"]

    namespace :generate do
      desc "Generates all swagger docs"
      task all: [:service_management]

      task :service_management do
        cmd = 'bundle exec source2swagger -f lib/3scale/backend/listener.rb -c "##~" -o docs/active_docs/.'
        run_command cmd
        # source2swagger is really bad at generating readable JSON
        require 'json'
        File.write('docs/active_docs/Service Management API.json',
                   JSON.pretty_generate(JSON.parse(
                     File.read('docs/active_docs/Service Management API.json'))) << "\n")
      end
    end

    namespace :upload do
      desc "Uploads all swagger docs"
      task all: [:service_management]

      task :service_management do
        require 'uri' unless Kernel.const_defined? :URI
        endpoint = URI.encode(
          File.readlines('docs/active_docs/endpoint').find do |line|
            line !~ /\A\s*(#.*)?\n?\z/
          end.chomp)
        run_command 'curl -v -X PUT -F "body=@docs/active_docs/Service Management API.json" ' + "\"#{endpoint}\""
      end
    end
  end
end
