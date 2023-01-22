# frozen_string_literal: true

require 'forwardable'
require 'sidekiq'
require 'sidekiq/manager'
require 'sidekiq/api'

module Sidekiq
  module LimitFetch
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

    def post_7?
      @post_7 ||= Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new('7.0.0')
    end

    def post_6_5?
      @post_6_5 ||= Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new('6.5.0')
    end

    RedisBaseConnectionError = post_7? ? RedisClient::ConnectionError : Redis::BaseConnectionError
    RedisCommandError = post_7? ? RedisClient::CommandError : Redis::CommandError

    def new(_)
      self
    end

    def retrieve_work
      queue, job = redis_brpop(Queues.acquire)
      Queues.release_except(queue)
      UnitOfWork.new(queue, job) if job
    end

    def config
      # Post 6.5, Sidekiq.options is deprecated and replaced with passing Sidekiq directly
      post_6_5? ? Sidekiq : Sidekiq.options
    end

    # Backwards compatibility for sidekiq v6.1.0
    # @see https://github.com/mperham/sidekiq/pull/4602
    def bulk_requeue(*args)
      if Sidekiq::BasicFetch.respond_to?(:bulk_requeue) # < 6.1.0
        Sidekiq::BasicFetch.bulk_requeue(*args)
      else # 6.1.0+
        Sidekiq::BasicFetch.new(post_7? ? Sidekiq.default_configuration.default_capsule : config).bulk_requeue(*args)
      end
    end

    def redis_retryable
      yield
    rescue RedisBaseConnectionError
      sleep TIMEOUT
      retry
    rescue RedisCommandError => e
      # If Redis was restarted and is still loading its snapshot,
      # then we should treat this as a temporary connection error too.
      raise unless e.message =~ /^LOADING/

      sleep TIMEOUT
      retry
    end

    private

    # rubocop:disable Metrics/MethodLength
    def redis_brpop(queues)
      if queues.empty?
        sleep TIMEOUT  # there are no queues to handle, so lets sleep
        []             # and return nothing
      else
        redis_retryable do
          Sidekiq.redis do |it|
            if post_7?
              it.blocking_call(false, 'brpop', *queues, TIMEOUT)
            else
              it.brpop(*queues, timeout: TIMEOUT)
            end
          end
        end
      end
    end
    # rubocop:enable Metrics/MethodLength
  end
end
