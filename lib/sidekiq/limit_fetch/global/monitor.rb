module Sidekiq::LimitFetch::Global
  module Monitor
    extend self

    HEARTBEAT_PREFIX = 'limit:heartbeat:'
    PROCESS_SET = 'limit:processes'
    HEARTBEAT_TTL = 20
    REFRESH_TIMEOUT = 5

    def start!(ttl=HEARTBEAT_TTL, timeout=REFRESH_TIMEOUT)
      Thread.new do
        loop do
          Sidekiq::LimitFetch.redis_retryable do
            add_dynamic_queues
            update_heartbeat ttl
            invalidate_old_processes
          end

          sleep timeout
        end
      end
    end

    def all_processes
      Sidekiq.redis {|it| it.smembers PROCESS_SET }
    end

    def old_processes
      all_processes.reject do |process|
        Sidekiq.redis {|it| it.get heartbeat_key process }
      end
    end

    def remove_old_processes!
      Sidekiq.redis do |it|
        old_processes.each {|process| it.srem PROCESS_SET, process }
      end
    end

    def add_dynamic_queues
      queues = Sidekiq::LimitFetch::Queues
      available_queues = Sidekiq::Queue.all.map(&:name).reject do |it|
        queues.dynamic_exclude.include? it
      end
      queues.add available_queues if queues.dynamic?
    end

    private

    def update_heartbeat(ttl)
      Sidekiq.redis do |it|
        it.multi do
          it.set heartbeat_key, true
          it.sadd PROCESS_SET, Selector.uuid
          it.expire heartbeat_key, ttl
        end
      end
    end

    def invalidate_old_processes
      Sidekiq.redis do |it|
        remove_old_processes!
        processes = all_processes

        Sidekiq::Queue.instances.each do |queue|
          queue.remove_locks_except! processes
        end
      end
    end

    def heartbeat_key(process=Selector.uuid)
      HEARTBEAT_PREFIX + process
    end
  end
end
