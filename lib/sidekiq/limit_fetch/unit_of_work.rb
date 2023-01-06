# frozen_string_literal: true

module Sidekiq
  module LimitFetch
    class UnitOfWork < BasicFetch::UnitOfWork
      def initialize(queue, job)
        if post_6_5?
          super(queue, job, Sidekiq)
        else
          super
        end
        redis_retryable { Queue[queue_name].increase_busy }
      end

      def acknowledge
        redis_retryable { Queue[queue_name].decrease_busy }
        redis_retryable { Queue[queue_name].release }
      end

      def requeue
        super
        acknowledge
      end

      private

      def post_6_5?
        Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new('6.5.0')
      end

      def redis_retryable(&block)
        Sidekiq::LimitFetch.redis_retryable(&block)
      end
    end
  end
end
