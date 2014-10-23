require "singleton"

module Sidekiq
  class LimitFetch
    class Utils
      class Refresh
        def self.do!
          Sidekiq.redis { |conn| conn.set("limit_queue:refresh", 1) }
        end

        def self.do?
          (Sidekiq.redis { |conn| conn.get("limit_queue:refresh") }.to_i == 1)
        end

        def self.done!
          Sidekiq.redis { |conn| conn.set("limit_queue:refresh", 0) }
        end

        def self.done?
          !(Sidekiq.redis { |conn| conn.get("limit_queue:refresh") }.to_i == 1)
        end
      end
    end
  end
end