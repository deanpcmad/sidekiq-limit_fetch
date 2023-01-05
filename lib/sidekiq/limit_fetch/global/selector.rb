# frozen_string_literal: true

module Sidekiq
  module LimitFetch
    module Global
      module Selector
        extend self

        MUTEX_FOR_UUID = Mutex.new

        def acquire(queues, namespace)
          redis_eval :acquire, [namespace, uuid, queues]
        end

        def release(queues, namespace)
          redis_eval :release, [namespace, uuid, queues]
        end

        def uuid
          # - if we'll remove "@uuid ||=" from inside of mutex
          # then @uuid can be overwritten
          # - if we'll remove "@uuid ||=" from outside of mutex
          # then each read will lead to mutex
          @uuid ||= MUTEX_FOR_UUID.synchronize { @uuid || SecureRandom.uuid }
        end

        private

        def redis_eval(script_name, args)
          Sidekiq.redis do |it|
            it.evalsha send("redis_#{script_name}_sha"), [], args
          rescue Sidekiq::LimitFetch::RedisCommandError => e
            raise unless e.message.include? 'NOSCRIPT'

            if Sidekiq::LimitFetch.post_7?
              it.eval send("redis_#{script_name}_script"), 0, *args
            else
              it.eval send("redis_#{script_name}_script"), argv: args
            end
          end
        end

        def redis_acquire_sha
          @redis_acquire_sha ||= OpenSSL::Digest::SHA1.hexdigest redis_acquire_script
        end

        def redis_release_sha
          @redis_release_sha ||= OpenSSL::Digest::SHA1.hexdigest redis_release_script
        end

        def redis_acquire_script
          <<-LUA
        local namespace   = table.remove(ARGV, 1)..'limit_fetch:'
        local worker_name = table.remove(ARGV, 1)
        local queues      = ARGV
        local available   = {}
        local unblocked   = {}
        local locks
        local process_locks
        local blocking_mode

        for _, queue in ipairs(queues) do
          if not blocking_mode or unblocked[queue] then
            local probed_key        = namespace..'probed:'..queue
            local pause_key         = namespace..'pause:'..queue
            local limit_key         = namespace..'limit:'..queue
            local process_limit_key = namespace..'process_limit:'..queue
            local block_key         = namespace..'block:'..queue

            local paused, limit, process_limit, can_block =
              unpack(redis.call('mget',
                pause_key,
                limit_key,
                process_limit_key,
                block_key
              ))

            if not paused then
              limit = tonumber(limit)
              process_limit = tonumber(process_limit)

              if can_block or limit then
                locks = redis.call('llen', probed_key)
              end

              if process_limit then
                local all_locks = redis.call('lrange', probed_key, 0, -1)
                process_locks = 0
                for _, process in ipairs(all_locks) do
                  if process == worker_name then
                    process_locks = process_locks + 1
                  end
                end
              end

              if not blocking_mode then
                blocking_mode = can_block and locks > 0
              end

              if blocking_mode and can_block ~= 'true' then
                for unblocked_queue in string.gmatch(can_block, "[^,]+") do
                  unblocked[unblocked_queue] = true
                end
              end

              if (not limit or limit > locks) and
                 (not process_limit or process_limit > process_locks) then
                redis.call('rpush', probed_key, worker_name)
                table.insert(available, queue)
              end
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
          local probed_key = namespace..'probed:'..queue
          redis.call('lrem', probed_key, 1, worker_name)
        end
          LUA
        end
      end
    end
  end
end
