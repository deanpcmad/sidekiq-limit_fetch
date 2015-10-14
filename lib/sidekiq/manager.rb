module Sidekiq
  class Manager

    def start
      queues = Sidekiq::LimitFetch::Queues.new options.merge(namespace: Sidekiq::LimitFetch::Redis.determine_namespace)
      Sidekiq::LimitFetch::Global::Monitor.start! queues

      @workers.each do |x|
        x.start
      end
    end

  end
end
