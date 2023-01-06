# frozen_string_literal: true

require 'simplecov'
SimpleCov.start

require 'sidekiq/limit_fetch'

if Sidekiq::LimitFetch.post_7?
  Sidekiq.configure_embed do |config|
    config.logger = nil
  end
else
  Sidekiq.logger = nil
  Sidekiq.redis = { namespace: ENV.fetch('namespace', nil) }
end

RSpec.configure do |config|
  config.order = :random
  config.disable_monkey_patching!
  config.raise_errors_for_deprecations!
  config.before do
    Sidekiq::Queue.reset_instances!
    Sidekiq.redis do |it|
      clean_redis = lambda do |queue|
        it.pipelined do |pipeline|
          pipeline.del "limit_fetch:limit:#{queue}"
          pipeline.del "limit_fetch:process_limit:#{queue}"
          pipeline.del "limit_fetch:busy:#{queue}"
          pipeline.del "limit_fetch:probed:#{queue}"
          pipeline.del "limit_fetch:pause:#{queue}"
          pipeline.del "limit_fetch:block:#{queue}"
        end
      end

      clean_redis.call(name) if defined?(name)
      queues.each(&clean_redis) if defined?(queues) && queues.is_a?(Array)
    end
  end
end
