module Sidekiq::LimitFetch::Redis
  extend self

  # prevent blocking of fetcher
  # more bullet-proof and faster (O_O)
  # than using Celluloid::IO
  #
  # https://github.com/brainopia/sidekiq-limit_fetch/issues/41
  # explanation of why Future#value is beneficial here
  def nonblocking_redis
    redis do |redis|
      begin
        Celluloid::Future.new { yield redis }.value
      end
    end
  rescue Celluloid::Task::TerminatedError
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
