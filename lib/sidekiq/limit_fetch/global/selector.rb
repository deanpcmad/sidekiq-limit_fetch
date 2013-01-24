module Sidekiq::LimitFetch::Global
  module Selector
    extend self

    def acquire(queues)
      redis_eval :acquire, [namespace, uuid, queues]
    end

    def release(queues)
      redis_eval :release, [namespace, uuid, queues]
    end

    private

    def namespace
      @namespace ||= begin
        namespace = Sidekiq.options[:namespace]
        namespace + ':' if namespace
      end
    end

    def uuid
      @uuid ||= SecureRandom.uuid
    end

    def redis_eval(script_name, args)
      Sidekiq.redis do |it|
        begin
          it.evalsha send("redis_#{script_name}_sha"), argv: args
        rescue Redis::CommandError => error
          raise unless error.message.include? 'NOSCRIPT'
          it.eval send("redis_#{script_name}_script"), argv: args
        end
      end
    end

    def redis_acquire_sha
      @acquire_sha ||= Digest::SHA1.hexdigest redis_acquire_script
    end

    def redis_release_sha
      @release_sha ||= Digest::SHA1.hexdigest redis_release_script
    end

    def redis_acquire_script
      <<-LUA
        local namespace   = table.remove(ARGV, 1)..'limit_fetch:'
        local worker_name = table.remove(ARGV, 1)
        local queues      = ARGV
        local available   = {}

        for _, queue in ipairs(queues) do
          local busy_key    = namespace..'busy:'..queue
          local pause_key   = namespace..'pause:'..queue
          local paused      = redis.call('get', pause_key)

          if not paused then
            local limit_key   = namespace..'limit:'..queue
            local queue_limit = tonumber(redis.call('get', limit_key))

            if queue_limit then
              local queue_locks = redis.call('llen', busy_key)

              if queue_limit > queue_locks then
                redis.call('rpush', busy_key, worker_name)
                table.insert(available, queue)
              end
            else
              redis.call('rpush', busy_key, worker_name)
              table.insert(available, queue)
            end
          end
        end

        return available
      LUA
    end

    def redis_release_script
      <<-LUA
        local namespace   = table.remove(ARGV, 1)..'limit_fetch:'
        local worker_name = table.remove(ARGV, 1)
        local queues      = ARGV

        for _, queue in ipairs(queues) do
          local busy_key = namespace..'busy:'..queue
          redis.call('lrem', busy_key, 1, worker_name)
        end
      LUA
    end
  end
end
