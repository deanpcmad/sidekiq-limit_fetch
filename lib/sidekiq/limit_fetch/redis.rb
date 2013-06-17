module Sidekiq::LimitFetch::Redis
  # prevent blocking of fetcher
  # more bullet-proof and faster (O_O)
  # than using Celluloid::IO
  def redis
    Sidekiq.redis do |redis|
      begin
        Celluloid::Future.new { yield redis }.value
      end
    end
  rescue Celluloid::Task::TerminatedError
  end
end
