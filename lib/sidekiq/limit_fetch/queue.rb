class Sidekiq::LimitFetch
  class Queue
    extend Forwardable

    attr_reader :name, :full_name
    def_delegators :@lock, :acquire, :release

    def initialize(name, limit)
      @name = name
      @full_name = "queue:#{name}"
      @lock = Semaphore.for limit
    end
  end
end
