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
          it.sadd PROCESS_SET, Selector.uuid
          it.set heartbeat_key, true
          it.expire heartbeat_key, ttl
        end
      end
    end

    def invalidate_old_processes
      Sidekiq.redis do |it|
        it.smembers(PROCESS_SET).each do |process|
          next if it.get heartbeat_key process

          Sidekiq::Queue.instances.map(&:name).uniq.each do |queue|
            %w(limit_fetch:probed: limit_fetch:busy:).each do |prefix|
              it.lrem prefix + queue, 0, process
            end
          end

          it.srem PROCESS_SET, process
        end
      end
    end

    def heartbeat_key(process=Selector.uuid)
      HEARTBEAT_PREFIX + process
    end
  end
end
