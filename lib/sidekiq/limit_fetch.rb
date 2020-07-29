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
    queue, job = redis_brpop(Queues.acquire)
    Queues.release_except(queue)
    UnitOfWork.new(queue, job) if job
  end

  def bulk_requeue(*args)
    klass = Sidekiq::BasicFetch
    fetch = klass.respond_to?(:bulk_requeue) ? klass : klass.new(Sidekiq::options)
    fetch.bulk_requeue(*args)
  end

  def redis_retryable
    yield
  rescue Redis::BaseConnectionError
    sleep 1
    retry
  end

  private

  TIMEOUT = Sidekiq::BasicFetch::TIMEOUT

  def redis_brpop(queues)
    if queues.empty?
      sleep TIMEOUT  # there are no queues to handle, so lets sleep
      []             # and return nothing
    else
      redis_retryable { Sidekiq.redis { |it| it.brpop *queues, TIMEOUT } }
    end
  end
end
