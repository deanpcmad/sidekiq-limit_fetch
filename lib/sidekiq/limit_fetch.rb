require 'sidekiq'
require 'sidekiq/util'
require 'sidekiq/api'
require 'forwardable'

class Sidekiq::LimitFetch
  autoload :UnitOfWork, 'sidekiq/limit_fetch/unit_of_work'

  require_relative 'limit_fetch/redis'
  require_relative 'limit_fetch/singleton'
  require_relative 'limit_fetch/queues'
  require_relative 'limit_fetch/global/semaphore'
  require_relative 'limit_fetch/global/selector'
  require_relative 'limit_fetch/global/monitor'
  require_relative 'extensions/queue'

  include Redis
  Sidekiq.options[:fetch] = self

  def self.bulk_requeue(*args)
    Sidekiq::BasicFetch.bulk_requeue *args
  end

  def initialize(options)
    Global::Monitor.start!

    # Add Dynamic queues
    queues = Sidekiq::Queue.all.map{ |queue| queue.name }
    options[:queues] = options[:queues].concat(queues)
    @queues = Queues.new options.merge(namespace: determine_namespace)
  end

  def dynamic_queues
    queues = Sidekiq::Queue.all.map{ |queue| queue.name }
    @queues.add_queues(queues)
  end

  def retrieve_work
    dynamic_queues
    queue, message = fetch_message
    UnitOfWork.new queue, message if message
  end

  private

  def fetch_message
    queue, _ = redis_brpop *@queues.acquire, Sidekiq::Fetcher::TIMEOUT
  ensure
    @queues.release_except queue
  end

  def redis_brpop(*args)
    return if args.size < 2
    query = -> redis { redis.brpop *args }

    if busy_local_queues.any? {|queue| not args.include? queue.rname }
      nonblocking_redis(&query)
    else
      redis(&query)
    end
  end

  def busy_local_queues
    Sidekiq::Queue.instances.select(&:local_busy?)
  end
end