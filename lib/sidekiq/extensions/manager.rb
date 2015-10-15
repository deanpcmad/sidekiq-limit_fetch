class Sidekiq::Manager
  module InitLimitFetch
    def initialize(options={})
      options[:fetch] = Sidekiq::LimitFetch
      super
    end

    def start
      Sidekiq::LimitFetch::Queues.start options
      Sidekiq::LimitFetch::Global::Monitor.start!
      super
    end
  end

  prepend InitLimitFetch
end
