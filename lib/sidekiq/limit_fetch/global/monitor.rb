module Sidekiq::LimitFetch::Global
  module Monitor
    extend self

    HEARTBEAT_NAMESPACE = 'heartbeat:'
    PROCESSOR_NAMESPACE = 'processor:'

    HEARTBEAT_TTL   = 18
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
          it.set processor_key, true
          it.set heartbeat_key, true
          it.expire heartbeat_key, ttl
        end
      end
    end

    def invalidate_old_processors
      Sidekiq.redis do |it|
        it.keys(PROCESSOR_NAMESPACE + '*').each do |processor|
          processor.sub! PROCESSOR_NAMESPACE, ''
          next if it.get heartbeat_key processor

          it.del processor_key processor
          it.keys('limit_fetch:busy:*').each do |queue|
            it.lrem queue, 0, processor
          end
        end
      end
    end

    def heartbeat_key(processor=Selector.uuid)
      HEARTBEAT_NAMESPACE + processor
    end

    def processor_key(processor=Selector.uuid)
      PROCESSOR_NAMESPACE + processor
    end
  end
end
