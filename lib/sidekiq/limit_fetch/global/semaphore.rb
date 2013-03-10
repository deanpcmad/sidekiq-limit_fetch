module Sidekiq::LimitFetch::Global
  class Semaphore
    extend Forwardable
    def_delegator Sidekiq, :redis

    PREFIX = 'limit_fetch'

    def initialize(name)
      @name = name
    end

    def limit
      value = redis {|it| it.get "#{PREFIX}:limit:#@name" }
      value.to_i if value
    end

    def limit=(value)
      redis {|it| it.set "#{PREFIX}:limit:#@name", value }
    end

    def acquire
      Selector.acquire([@name]).size > 0
    end

    def release
      Selector.release [@name]
    end

    def busy
      redis {|it| it.llen "#{PREFIX}:busy:#@name" }
    end

    def pause
      redis {|it| it.set "#{PREFIX}:pause:#@name", true }
    end

    def unpause
      redis {|it| it.del "#{PREFIX}:pause:#@name" }
    end

    def paused?
      redis {|it| it.get "#{PREFIX}:pause:#@name" }
    end

    def block
      redis {|it| it.set "#{PREFIX}:block:#@name", true }
    end

    def block_except(*queues)
      raise ArgumentError if queues.empty?
      redis {|it| it.set "#{PREFIX}:block:#@name", queues.join(',') }
    end

    def unblock
      redis {|it| it.del "#{PREFIX}:block:#@name" }
    end

    def blocking?
      redis {|it| it.get "#{PREFIX}:block:#@name" }
    end
  end
end
