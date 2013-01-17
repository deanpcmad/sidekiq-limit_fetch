module Sidekiq
  class Queue
    extend LimitFetch::Singleton, Forwardable

    def_delegators :lock,
      :limit,   :limit=,
      :acquire, :release,
      :pause,   :continue,
      :busy

    def full_name
      @rname
    end

    def lock
      @lock ||= LimitFetch::Semaphore.new
    end
  end
end
