class Sidekiq::LimitFetch::Semaphore
  Stub = Struct.new(:acquire, :release)

  def self.for(limit)
    limit ? new(limit) : stub
  end

  def self.stub
    @stub ||= Stub.new(true, true)
  end

  def initialize(limit)
    @lock  = Mutex.new
    @limit = limit
  end

  def acquire
    @lock.synchronize do
      @limit -= 1 if @limit > 0
    end
  end

  def release
    @lock.synchronize do
      @limit += 1
    end
  end
end
