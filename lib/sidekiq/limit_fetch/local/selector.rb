module Sidekiq::LimitFetch::Local
  module Selector
    extend self

    def acquire(names)
      queues(names).select(&:acquire).map(&:name)
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
