namespace :request_logs do

  desc 'Global Request Logs enable, requires per-service enable afterwards'
  task :enable do
    request_logs.global_enable
  end

  desc 'Global Request Logs disable'
  task :disable do
    request_logs.global_disable
  end

  desc 'Ask whether Request Logs are globally enabled'
  task :globally_enabled do
    STDOUT.puts "#{request_logs.globally_enabled?.inspect}"
  end

  desc 'Ask whether a specific service is enabled'
  task :service_enabled, [:service_id] do |_, args|
    STDOUT.puts "#{request_logs.service_enabled?(args[:service_id]).inspect}"
  end

  desc 'Enable service'
  task :enable_service, [:service_id] do |_, args|
    request_logs.enable_service args[:service_id]
  end

  desc 'Disable service'
  task :disable_service, [:service_id] do |_, args|
    request_logs.disable_service args[:service_id]
  end

  desc 'Disables Request Logs and cleans all the related keys'
  task :clean => :rm_plain_keys do
    request_logs.clean_cubert_redis_keys
  end

  # this task to be removed after cleaning plain keys
  desc 'Remove unneeded plain keys taking storage space'
  task :rm_plain_keys do
    storage.smembers(request_logs.const_get :SERVICES_SET_KEY).each_slice(slice_size) do |s|
      storage.del s
    end
  end

  def slice_size
    ThreeScale::PIPELINED_SLICE_SIZE
  end

  def request_logs
    ThreeScale::Backend::RequestLogs::Management
  end

  def storage
    ThreeScale::Backend::Storage.instance
  end
end
