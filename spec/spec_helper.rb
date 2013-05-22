require 'sidekiq/limit_fetch'
require 'celluloid/autostart'
require 'sidekiq/fetch'

RSpec.configure do |config|
  config.before :each do
    Sidekiq::Queue.instance_variable_set :@instances, {}
    Sidekiq.options[:local] = defined?(local) ? local : nil

    Sidekiq.redis do |it|
      clean_redis = ->(queue) do
        it.del "limit_fetch:limit:#{queue}"
        it.del "limit_fetch:busy:#{queue}"
        it.del "limit_fetch:pause:#{queue}"
        it.del "limit_fetch:block:#{queue}"
      end

      clean_redis.call(name) if defined?(name)
      queues.each(&clean_redis) if defined?(queues) and queues.is_a? Array
    end
  end
end
