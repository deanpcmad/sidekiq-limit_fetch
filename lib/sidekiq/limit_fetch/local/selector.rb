module Sidekiq::LimitFetch::Local
  module Selector
    extend self

    def acquire(names)
      blocked   = false
      unblocked = []

      queues(names).select {|queue|
        next false if blocked and not unblocked.include?(queue.name)

        if not queue.paused? and queue.blocking? and queue.busy > 0
          blocked   = true
          unblocked = queue.unblocked || []
        end

        queue.acquire
      }.map(&:name)
    end

    def release(names)
      queues(names).each(&:release)
    end

    private

    def queues(names)
      names.map {|name| Sidekiq::Queue[name] }
    end
  end
end
