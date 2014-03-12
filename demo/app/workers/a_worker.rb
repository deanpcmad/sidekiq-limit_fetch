class AWorker
  include Sidekiq::Worker
  sidekiq_options queue: :a

  def perform
    sleep 10
  end
end
