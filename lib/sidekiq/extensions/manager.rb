# frozen_string_literal: true

module Sidekiq
  class Manager
    module InitLimitFetch
      def initialize(capsule_or_options)
        if Sidekiq::LimitFetch.post_7?
          capsule_or_options.config[:fetch_class] = Sidekiq::LimitFetch
        else
          capsule_or_options[:fetch] = Sidekiq::LimitFetch
        end
        super
      end

      def start
        # In sidekiq 6.5.0 the variable @options has been renamed to @config
        Sidekiq::LimitFetch::Queues.start @options || @config
        Sidekiq::LimitFetch::Global::Monitor.start!
        super
      end
    end

    prepend InitLimitFetch
  end
end
