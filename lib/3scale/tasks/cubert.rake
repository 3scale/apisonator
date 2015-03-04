namespace :cubert do

  desc 'Global cubert enable, requires per-service enable afterwards'
  task :enable => :environment do
    ThreeScale::Backend::CubertServiceManagementUseCase.global_enable
  end

  desc 'Global cubert disable'
  task :disable => :environment do
    ThreeScale::Backend::CubertServiceManagementUseCase.global_disable
  end

  desc 'Enable cubert for service'
  task :enable_service, [:service_id] => :environment do |_task, args|
    ThreeScale::Backend::CubertServiceManagementUseCase.
      new(args[:service_id]).enable_service
  end

  desc 'Disable cubert for service'
  task :disable_service, [:service_id] => :environment do |_task, args|
    ThreeScale::Backend::CubertServiceManagementUseCase.
      new(args[:service_id]).disable_service
  end

  desc 'Disables Cuberta and cleans all the related keys'
  task :clean => :environment do
    ThreeScale::Backend::CubertServiceManagementUseCase.clean_cubert_redis_keys
  end

  def storage
    ThreeScale::Backend::Storage.instance
  end
end
