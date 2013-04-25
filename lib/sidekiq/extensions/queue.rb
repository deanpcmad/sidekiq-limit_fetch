module Sidekiq
  class Queue
    extend LimitFetch::Singleton, Forwardable

    def_delegators :lock,
      :limit,     :limit=,
      :acquire,   :release,
      :pause,     :unpause,
      :block,     :unblock,
      :paused?,   :blocking?,
      :unblocked, :block_except,
      :busy

    def lock
      @lock ||= mode::Semaphore.new name
    end

    def mode
      Sidekiq.options[:local] ? LimitFetch::Local : LimitFetch::Global
    end
  end
end
