# frozen_string_literal: true

class BWorker
  include Sidekiq::Worker
  sidekiq_options queue: :b

  def perform
    sleep 10
  end
end
