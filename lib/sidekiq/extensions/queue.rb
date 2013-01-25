module Sidekiq
  class Queue
    extend LimitFetch::Singleton, Forwardable

    def_delegators :lock,
      :limit,   :limit=,
      :acquire, :release,
      :pause,   :unpause,
      :block,   :unblock,
      :paused?, :blocking?,
      :busy

    def lock
      @lock ||= mode::Semaphore.new name
    end

    def mode
      Sidekiq.options[:global] ? LimitFetch::Global : LimitFetch::Local
    end
  end
end
