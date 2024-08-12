namespace :connectivity do
  desc 'Check connectivity of Redis Storage'
  task :redis_storage_check do
      redis_instance = ThreeScale::Backend::Storage.instance

      if Environment.using_async_redis?
        async_ping(redis_instance, 'storage')
      else
        ping(redis_instance, 'storage')
      end
  end

  desc 'Check connectivity of Redis Queue Storage'
  task :redis_storage_queue_check do
      redis_instance = ThreeScale::Backend::QueueStorage.connection(
        ThreeScale::Backend.environment,
        ThreeScale::Backend.configuration,
      )

      if Environment.using_async_redis?
        async_ping(redis_instance, 'queue storage')
      else
        ping(redis_instance, 'queue storage')
      end
  end

  private

  def async_ping(redis_instance, storage_type)
    Async { ping(redis_instance, storage_type) }
  end

  def ping(redis_instance, storage_type, attempts = 3)
    attempts -= 1
    redis_instance.ping
  rescue => e
    warn "Error connecting to Redis #{storage_type}: #{e}"
    exit(false) unless attempts > 0
    sleep 1
    retry
  else
    puts "Connection to Redis #{storage_type} performed successfully"
  end
end
