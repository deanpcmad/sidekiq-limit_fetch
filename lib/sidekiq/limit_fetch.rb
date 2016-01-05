require 'forwardable'
require 'sidekiq'
require 'sidekiq/manager'
require 'sidekiq/api'

module Sidekiq::LimitFetch
  autoload :UnitOfWork, 'sidekiq/limit_fetch/unit_of_work'

  require_relative 'limit_fetch/instances'
  require_relative 'limit_fetch/queues'
  require_relative 'limit_fetch/global/semaphore'
  require_relative 'limit_fetch/global/selector'
  require_relative 'limit_fetch/global/monitor'
  require_relative 'extensions/queue'
  require_relative 'extensions/manager'

  extend self

  def new(_)
    self
  end

  def retrieve_work
    queue, job = redis_brpop *Queues.acquire, Sidekiq::BasicFetch::TIMEOUT
    Queues.release_except(queue)
    UnitOfWork.new(queue, job) if job
  end

  def bulk_requeue(*args)
    Sidekiq::BasicFetch.bulk_requeue(*args)
  end

  private

  def redis_brpop(*args)
    return if args.size < 2
    Sidekiq.redis {|it| it.brpop *args }
  end
end
