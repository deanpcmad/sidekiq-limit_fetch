class Sidekiq::LimitFetch::Semaphore
  attr_reader :limit, :busy

  def initialize
    @lock = Mutex.new
    @busy = 0
  end

  def limit=(value)
    @lock.synchronize do
      @limit = value
    end
  end

  def acquire
    @lock.synchronize do
      @busy += 1 if not @limit or @limit > @busy
    end
  end

  def release
    @lock.synchronize do
      @busy -= 1
    end
  end
end
