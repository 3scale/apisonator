namespace :connectivity do
  desc 'Check connectivity of Redis Storage'
  task :redis_storage_check do
    begin
      redis_instance = ThreeScale::Backend::Storage.instance
      redis_instance.ping
    rescue => e
      warn "Error connecting to Redis Storage: #{e}"
      exit(false)
    else
      puts "Connection to Redis Storage (#{redis_instance.id}) performed successfully"
    end
  end

  desc 'Check connectivity of Redis Queue Storage'
  task :redis_storage_queue_check do
    begin
      redis_instance = ThreeScale::Backend::QueueStorage.connection(
        ThreeScale::Backend.environment,
        ThreeScale::Backend.configuration,
      )
      redis_instance.ping
    rescue => e
      warn "Error connecting to Redis Queue Storage: #{e}"
      exit(false)
    else
      puts "Connection to Redis Queue Storage (#{redis_instance.id}) performed successfully"
    end
  end

end
