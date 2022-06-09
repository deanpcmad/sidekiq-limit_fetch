class Sidekiq::Manager
  module InitLimitFetch
    def initialize(options={})
      options[:fetch] = Sidekiq::LimitFetch
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
