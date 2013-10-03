class SlowWorker
  include Sidekiq::Worker
  sidekiq_options queue: :slow

  def perform
    sleep 1
  end
end
