require 'sidekiq'
require 'sidekiq/fetch'

class Sidekiq::LimitFetch
  require_relative 'limit_fetch/semaphore'
  require_relative 'limit_fetch/unit_of_work'
  require_relative 'limit_fetch/singleton'
  require_relative 'limit_fetch/queue'

  Sidekiq.options[:fetch] = self

  def self.bulk_requeue(jobs)
    Sidekiq::BasicFetch.bulk_requeue jobs
  end

  def initialize(options)
    prepare_queues options
    options[:strict] ? define_strict_queues : define_weighted_queues
  end

  def available_queues
    fetch_queues.select(&:acquire)
  end

  def retrieve_work
    queues = available_queues

    if queues.empty?
      sleep Sidekiq::Fetcher::TIMEOUT
      return
    end

    queue_name, message = Sidekiq.redis do |it|
      it.brpop *queues.map(&:full_name), Sidekiq::Fetcher::TIMEOUT
    end

    if message
      queue = queues.delete queues.find {|it| it.full_name == queue_name }
      UnitOfWork.new queue, message
    end
  ensure
    queues.each(&:release) if queues
  end

  private

  def prepare_queues(options)
    limits = options[:limits] || {}
    @queues = options[:queues].map do |name|
      Sidekiq::Queue.new(name).tap do |it|
        it.limit = limits[name] if limits[name]
      end
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
