module Sidekiq::LimitFetch::Global
  class Semaphore
    PREFIX = 'limit_fetch'

    def initialize(name)
      @name = name
    end

    def limit
      value = Sidekiq.redis {|it| it.get "#{PREFIX}:limit:#@name" }
      value.to_i if value
    end

    def limit=(value)
      Sidekiq.redis {|it| it.set "#{PREFIX}:limit:#@name", value }
    end

    def acquire
      Selector.acquire([@name]).size > 0
    end

    def release
      Selector.release [@name]
    end

    def busy
      Sidekiq.redis {|it| it.llen "#{PREFIX}:busy:#@name" }
    end

    def pause
      Sidekiq.redis {|it| it.set "#{PREFIX}:pause:#@name", true }
    end

    def continue
      Sidekiq.redis {|it| it.del "#{PREFIX}:pause:#@name" }
    end
  end
end
