namespace :cubert do

  desc 'Global cubert enable. Requires per-service enable afterwards.'
  task :enable => :environment do
    ThreeScale::Backend::LogRequestCubertStorage.global_enable
  end

  desc 'Global cubert disable.'
  task :disable => :environment do
    ThreeScale::Backend::LogRequestCubertStorage.global_disable
  end

  desc 'Enable cubert for service. Usage: bundle exec rake cubert:enable_service 5'
  task :enable_service => :environment do
    ThreeScale::Backend::LogRequestCubertStorage.enable_service ARGV.last.to_i
  end

  desc 'Disable cubert for service.'
  task :disable_service => :environment do
    ThreeScale::Backend::LogRequestCubertStorage.disable_service ARGV.last.to_i
  end

  def storage
    ThreeScale::Backend::Storage.instance
  end
end
