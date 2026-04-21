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
        Queue[queue_name].lock.decrease_local_busy

        redis_retryable do
          Sidekiq.redis do |conn|
            conn.multi do |pipeline|
              pipeline.lrem busy_key, 1, Sidekiq::LimitFetch::Global::Selector.uuid
              pipeline.lrem probed_key, 1, Sidekiq::LimitFetch::Global::Selector.uuid
            end
          end
        end
      end

      def requeue
        super
        acknowledge
      end

      private

      def post_6_5?
        Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new('6.5.0')
      end

      def busy_key
        "#{Sidekiq::LimitFetch::Global::Semaphore::PREFIX}:busy:#{queue_name}"
      end

      def probed_key
        "#{Sidekiq::LimitFetch::Global::Semaphore::PREFIX}:probed:#{queue_name}"
      end

      def redis_retryable(&block)
        Sidekiq::LimitFetch.redis_retryable(&block)
      end
    end
  end
end
