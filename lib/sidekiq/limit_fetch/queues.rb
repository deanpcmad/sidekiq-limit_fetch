# frozen_string_literal: true

module Sidekiq
  module LimitFetch
    module Queues
      extend self

      THREAD_KEY = :acquired_queues

      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/PerceivedComplexity
      def start(capsule_or_options)
        config = Sidekiq::LimitFetch.post_7? ? capsule_or_options.config : capsule_or_options

        @queues = config[:queues].map do |queue|
          if queue.is_a? Array
            queue.first
          else
            queue
          end
        end.uniq
        @startup_queues = @queues.dup

        if config[:dynamic].is_a? Hash
          @dynamic         = true
          @dynamic_exclude = config[:dynamic][:exclude] || []
        else
          @dynamic = config[:dynamic]
          @dynamic_exclude = []
        end

        @limits         = config[:limits] || {}
        @process_limits = config[:process_limits] || {}
        @blocks         = config[:blocking] || []

        config[:strict] ? strict_order! : weighted_order!

        apply_process_limit_to_queues
        apply_limit_to_queues
        apply_blocks_to_queues
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/PerceivedComplexity

      def acquire
        queues = saved
        queues ||= Sidekiq::LimitFetch.redis_retryable do
          selector.acquire(ordered_queues, namespace)
        end
        save queues
        queues.map { |it| "queue:#{it}" }
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

      def startup_queue?(queue)
        @startup_queues.include?(queue)
      end

      def dynamic_exclude
        @dynamic_exclude
      end

      def add(queues)
        return unless queues

        queues.each do |queue|
          next if @queues.include? queue

          if startup_queue?(queue)
            apply_process_limit_to_queue(queue)
            apply_limit_to_queue(queue)
          end

          @queues.push queue
        end
      end

      def remove(queues)
        return unless queues

        queues.each do |queue|
          next unless @queues.include? queue

          clear_limits_for_queue(queue)
          @queues.delete queue
          Sidekiq::Queue.delete_instance(queue)
        end
      end

      def handle(queues)
        add(queues - @queues)
        remove(@queues - queues)
      end

      # rubocop:disable Lint/NestedMethodDefinition
      def strict_order!
        @queues.uniq!
        def ordered_queues
          @queues
        end
      end

      def weighted_order!
        def ordered_queues
          @queues.shuffle.uniq
        end
      end
      # rubocop:enable Lint/NestedMethodDefinition

      def namespace
        @namespace ||= Sidekiq.redis do |it|
          if it.respond_to?(:namespace) && it.namespace
            "#{it.namespace}:"
          else
            ''
          end
        end
      end

      private

      def apply_process_limit_to_queues
        @queues.uniq.each do |queue_name|
          apply_process_limit_to_queue(queue_name)
        end
      end

      def apply_process_limit_to_queue(queue_name)
        queue = Sidekiq::Queue[queue_name]
        queue.process_limit = @process_limits[queue_name.to_s] || @process_limits[queue_name.to_sym]
      end

      def apply_limit_to_queues
        @queues.uniq.each do |queue_name|
          apply_limit_to_queue(queue_name)
        end
      end

      def apply_limit_to_queue(queue_name)
        queue = Sidekiq::Queue[queue_name]

        return if queue.limit_changed?

        queue.limit = @limits[queue_name.to_s] || @limits[queue_name.to_sym]
      end

      def apply_blocks_to_queues
        @queues.uniq.each do |queue_name|
          Sidekiq::Queue[queue_name].unblock
        end

        @blocks.to_a.each do |it|
          if it.is_a? Array
            it.each { |name| Sidekiq::Queue[name].block_except it }
          else
            Sidekiq::Queue[it].block
          end
        end
      end

      def clear_limits_for_queue(queue_name)
        queue = Sidekiq::Queue[queue_name]
        queue.clear_limits
      end

      def selector
        Sidekiq::LimitFetch::Global::Selector
      end

      def saved
        Thread.current[THREAD_KEY]
      end

      def save(queues)
        Thread.current[THREAD_KEY] = queues
      end

      def restore
        saved || []
      ensure
        save nil
      end
    end
  end
end
