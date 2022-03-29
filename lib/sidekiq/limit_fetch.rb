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

  TIMEOUT = Sidekiq::BasicFetch::TIMEOUT

  extend self

  def new(_)
    self
  end

  def retrieve_work
    queue, job = redis_brpop(Queues.acquire)
    Queues.release_except(queue)
    UnitOfWork.new(queue, job) if job
  end

  # Backwards compatibility for sidekiq v6.1.0
  # @see https://github.com/mperham/sidekiq/pull/4602
  def bulk_requeue(*args)
    if Sidekiq::BasicFetch.respond_to?(:bulk_requeue) # < 6.1.0
      Sidekiq::BasicFetch.bulk_requeue(*args)
    else # 6.1.0+
      Sidekiq::BasicFetch.new(Sidekiq.options).bulk_requeue(*args)
    end
  end

  def redis_retryable
    yield
  rescue Redis::BaseConnectionError
    sleep TIMEOUT
    retry
  rescue Redis::CommandError => error
    # If Redis was restarted and is still loading its snapshot,
    # then we should treat this as a temporary connection error too.
    if error.message =~ /^LOADING/
      sleep TIMEOUT
      retry
    else
      raise
    end
  end

  private

  def redis_brpop(queues)
    if queues.empty?
      sleep TIMEOUT  # there are no queues to handle, so lets sleep
      []             # and return nothing
    else
      redis_retryable { Sidekiq.redis { |it| it.brpop *queues, TIMEOUT } }
    end
  end
end
