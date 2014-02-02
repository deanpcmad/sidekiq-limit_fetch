module Sidekiq::LimitFetch::Global
  module Monitor
    extend self

    HEARTBEAT_PREFIX = 'heartbeat:'
    PROCESS_SET = 'processes'
    HEARTBEAT_TTL = 18
    REFRESH_TIMEOUT = 10

    def start!(ttl=HEARTBEAT_TTL, timeout=REFRESH_TIMEOUT)
      Thread.new do
        loop do
          update_heartbeat ttl
          invalidate_old_processes
          sleep timeout
        end
      end
    end

    private

    def update_heartbeat(ttl)
      Sidekiq.redis do |it|
        it.pipelined do
          it.set heartbeat_key, true
          it.sadd PROCESS_SET, Selector.uuid
          it.expire heartbeat_key, ttl
        end
      end
    end

    def invalidate_old_processes
      Sidekiq.redis do |it|
        processes = it.smembers PROCESS_SET
        processes.each do |process|
          unless it.get heartbeat_key process
            processes.delete process
            it.srem PROCESS_SET, process
          end
        end

        Sidekiq::Queue.instances.map(&:name).uniq.each do |queue|
          locks = it.lrange "limit_fetch:probed:#{queue}", 0, -1
          (locks.uniq - processes).each do |dead_process|
            %w(limit_fetch:probed: limit_fetch:busy:).each do |prefix|
              it.lrem prefix + queue, 0, dead_process
            end
          end
        end
      end
    end

    def heartbeat_key(process=Selector.uuid)
      HEARTBEAT_PREFIX + process
    end
  end
end
