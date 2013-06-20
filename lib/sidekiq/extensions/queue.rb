module Sidekiq
  class Queue
    extend LimitFetch::Singleton, Forwardable
    attr_reader :rname

    def_delegators :lock,
      :limit,         :limit=,
      :acquire,       :release,
      :pause,         :unpause,
      :block,         :unblock,
      :paused?,       :blocking?,
      :unblocked,     :block_except,
      :probed,        :busy,
      :increase_busy, :decrease_busy,
      :local_busy?

    def lock
      @lock ||= LimitFetch::Global::Semaphore.new name
    end
  end
end
