module Sidekiq
  class LimitFetch::UnitOfWork < BasicFetch::UnitOfWork
    def acknowledge
      Queue[queue_name].release
    end

    def requeue
      super
      acknowledge
    end
  end
end
