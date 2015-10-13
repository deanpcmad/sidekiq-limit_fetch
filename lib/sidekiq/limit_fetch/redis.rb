module Sidekiq::LimitFetch::Redis
  extend self

  def nonblocking_redis
    redis do |redis|
      yield redis
    end
  end

  def redis
    Sidekiq.redis {|it| yield it }
  end

  def determine_namespace
    redis do |it|
      if it.respond_to?(:namespace) and it.namespace
        it.namespace + ':'
      end
    end
  end
end
