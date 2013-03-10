module Sidekiq::LimitFetch::Local
  class Semaphore
    attr_reader :limit, :busy, :unblocked

    def initialize(name)
      @name = name
      @lock = Mutex.new
      @busy = 0
      @paused = false
    end

    def limit=(value)
      @lock.synchronize do
        @limit = value
      end
    end

    def acquire
      return if @paused
      @lock.synchronize do
        @busy += 1 if not @limit or @limit > @busy
      end
    end

    def release
      @lock.synchronize do
        @busy -= 1
      end
    end

    def pause
      @paused = true
    end

    def unpause
      @paused = false
    end

    def paused?
      @paused
    end

    def block
      @block = true
    end

    def block_except(*queues)
      raise ArgumentError if queues.empty?
      @unblocked = queues
      @block = true
    end

    def unblock
      @block = false
    end

    def blocking?
      @block
    end
  end
end
