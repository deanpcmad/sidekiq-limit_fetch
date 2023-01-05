# frozen_string_literal: true

class FastWorker
  include Sidekiq::Worker
  sidekiq_options queue: :fast

  def perform
    sleep 0.2
  end
end
