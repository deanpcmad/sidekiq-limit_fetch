require 'sidekiq'
require 'sidekiq/fetch'

class Sidekiq::LimitFetch
  require_relative 'limit_fetch/semaphore'
  require_relative 'limit_fetch/queue'
  require_relative 'limit_fetch/unit_of_work'

  Sidekiq.options[:fetch] = self

  def initialize(options)
    prepare_queues options
    options[:strict] ? define_strict_queues : define_weighted_queues
  end

  def available_queues
    fetch_queues.select(&:acquire)
  end

  def retrieve_work
    queues = available_queues
    queue_name, message = Sidekiq.redis do |it|
      it.brpop *queues.map(&:full_name), Sidekiq::Fetcher::TIMEOUT
    end

    if message
      queue = queues.find {|it| it.full_name == queue_name }
      queues.delete queue

      UnitOfWork.new queue, message
    end
  ensure
    queues.each(&:release) if queues
  end

  private

  def prepare_queues(options)
    cache = {}
    limits = options[:limits] || {}

    @queues = options[:queues].map do |name|
      cache[name] ||= Queue.new name, limits[name]
    end
  end

  def define_strict_queues
    @queues.uniq!
    def fetch_queues
      @queues
    end
  end

  def define_weighted_queues
    def fetch_queues
      @queues.shuffle.uniq
    end
  end
end
