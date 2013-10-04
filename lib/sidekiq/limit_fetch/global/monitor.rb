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
          invalidate_old_processors
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

    def invalidate_old_processors
      Sidekiq.redis do |it|
        it.smembers(PROCESS_SET).each do |processor|
          next if it.get heartbeat_key processor

          %w(limit_fetch:probed:* limit_fetch:busy:*).each do |pattern|
            it.keys(pattern).each do |queue|
              it.lrem queue, 0, processor
            end
          end

          it.srem processor
        end
      end
    end

    def heartbeat_key(processor=Selector.uuid)
      HEARTBEAT_PREFIX + processor
    end
  end
end
