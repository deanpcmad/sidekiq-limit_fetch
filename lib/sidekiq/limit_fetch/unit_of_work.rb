module Sidekiq
  class LimitFetch::UnitOfWork < BasicFetch::UnitOfWork
    def initialize(queue, message)
      super
      Queue[queue_name].increase_busy
    end

    def acknowledge
      Queue[queue_name].decrease_busy
      Queue[queue_name].release
    end

    def requeue
      super
      acknowledge
    end
  end
end
