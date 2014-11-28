namespace :cubert do

  desc 'Global cubert enable. Requires per-service enable afterwards.'
  task :global_enable => :environment do
    ThreeScale::Backend::LogRequestCubertStorage.global_enable
  end

  desc 'Global cubert disable.'
  task :global_disable => :environment do
    ThreeScale::Backend::LogRequestCubertStorage.global_disable
  end

  def storage
    ThreeScale::Backend::Storage.instance
  end
end
