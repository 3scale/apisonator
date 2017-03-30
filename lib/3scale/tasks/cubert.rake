namespace :cubert do

  desc 'Global Cubert enable, requires per-service enable afterwards'
  task :enable do
    cubert.global_enable
  end

  desc 'Global Cubert disable'
  task :disable do
    cubert.global_disable
  end

  desc 'Disables Cubert and cleans all the related keys'
  task :clean => :rm_plain_keys do
    cubert.clean_cubert_redis_keys
  end

  # this task to be removed after cleaning plain keys
  desc 'Remove unneeded plain keys taking storage space'
  task :rm_plain_keys do
    storage.smembers(cubert.send :all_bucket_keys_key).each_slice(slice_size) do |s|
      storage.del s
    end
  end

  def slice_size
    ThreeScale::PIPELINED_SLICE_SIZE
  end

  def cubert
    ThreeScale::Backend::CubertServiceManagementUseCase
  end

  def storage
    ThreeScale::Backend::Storage.instance
  end
end
