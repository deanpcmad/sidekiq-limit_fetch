class Sidekiq::LimitFetch
  class Queues
    THREAD_KEY = :acquired_queues
    attr_reader :selector

    def initialize(options)
      @queues = options[:queues]
      options[:strict] ? strict_order! : weighted_order!

      set_selector options[:global]
      set_limits options[:limits]
    end

    def acquire
      @selector.acquire(ordered_queues)
        .tap {|it| save it }
        .map {|it| "queue:#{it}" }
    end
    
    def release_except(full_name)
      @selector.release restore.delete_if {|name| full_name.to_s.include? name }
    end

    private

    def set_selector(global)
      @selector = global ? Global::Selector : Local::Selector
    end

    def set_limits(limits)
      ordered_queues.each do |name|
        Sidekiq::Queue[name].tap do |it|
          it.limit = (limits || {})[name]
        end
      end
    end

    def strict_order!
      @queues.uniq!
      def ordered_queues; @queues end
    end

    def weighted_order!
      def ordered_queues; @queues.shuffle.uniq end
    end

    def save(queues)
      Thread.current[THREAD_KEY] = queues
    end

    def restore
      Thread.current[THREAD_KEY]
    ensure
      Thread.current[THREAD_KEY] = nil
    end
  end
end
