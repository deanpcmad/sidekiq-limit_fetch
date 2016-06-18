module Sidekiq::LimitFetch::Queues
  extend self

  THREAD_KEY = :acquired_queues

  def start(options)
    @queues    = options[:queues]
    @dynamic   = options[:dynamic]

    options[:strict] ? strict_order! : weighted_order!

    set :process_limit, options[:process_limits]
    set :limit, options[:limits]
    set_blocks options[:blocking]
  end

  def acquire
    selector.acquire(ordered_queues, namespace)
      .tap {|it| save it }
      .map {|it| "queue:#{it}" }
  end

  def release_except(full_name)
    queues = restore
    queues.delete full_name[/queue:(.*)/, 1] if full_name

    Sidekiq::LimitFetch.redis_retryable do
      selector.release queues, namespace
    end
  end

  def dynamic?
    @dynamic
  end

  def add(queues)
    queues.each do |queue|
      @queues.push queue unless @queues.include? queue
    end
  end

  def strict_order!
    @queues.uniq!
    def ordered_queues; @queues end
  end

  def weighted_order!
    def ordered_queues; @queues.shuffle.uniq end
  end

  def namespace
    @namespace ||= Sidekiq.redis do |it|
      if it.respond_to?(:namespace) and it.namespace
        "#{it.namespace}:"
      else
        ''
      end
    end
  end

  private

  def selector
    Sidekiq::LimitFetch::Global::Selector
  end

  def set(limit_type, limits)
    limits ||= {}
    each_queue do |queue|
      limit = limits[queue.name.to_s] || limits[queue.name.to_sym]
      queue.send "#{limit_type}=", limit unless queue.limit_changed?
    end
  end

  def set_blocks(blocks)
    each_queue(&:unblock)

    blocks.to_a.each do |it|
      if it.is_a? Array
        it.each {|name| Sidekiq::Queue[name].block_except it }
      else
        Sidekiq::Queue[it].block
      end
    end
  end

  def save(queues)
    Thread.current[THREAD_KEY] = queues
  end

  def restore
    Thread.current[THREAD_KEY] || []
  ensure
    Thread.current[THREAD_KEY] = nil
  end

  def each_queue
    @queues.uniq.each {|it| yield Sidekiq::Queue[it] }
  end
end
