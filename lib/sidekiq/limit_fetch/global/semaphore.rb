module Sidekiq::LimitFetch::Global
  class Semaphore
    include Sidekiq::LimitFetch::Redis

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
      Selector.acquire([@name], determine_namespace).size > 0
    end

    def release
      redis {|it| it.lrem "#{PREFIX}:probed:#@name", 1, Selector.uuid }
    end

    def busy
      redis {|it| it.llen "#{PREFIX}:busy:#@name" }
    end

    def increase_busy
      redis {|it| it.rpush "#{PREFIX}:busy:#@name", Selector.uuid }
    end

    def decrease_busy
      redis {|it| it.lrem "#{PREFIX}:busy:#@name", 1, Selector.uuid }
    end

    def probed
      redis {|it| it.llen "#{PREFIX}:probed:#@name" }
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
