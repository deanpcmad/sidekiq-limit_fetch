# frozen_string_literal: true

module Sidekiq
  module LimitFetch
    module Global
      class Semaphore
        PREFIX = 'limit_fetch'

        attr_reader :local_busy

        def initialize(name)
          @name = name
          @lock = Mutex.new
          @local_busy = 0
        end

        def limit
          value = redis { |it| it.get "#{PREFIX}:limit:#{@name}" }
          value&.to_i
        end

        def limit=(value)
          @limit_changed = true

          if value
            redis { |it| it.set "#{PREFIX}:limit:#{@name}", value }
          else
            redis { |it| it.del "#{PREFIX}:limit:#{@name}" }
          end
        end

        def limit_changed?
          @limit_changed
        end

        def process_limit
          value = redis { |it| it.get "#{PREFIX}:process_limit:#{@name}" }
          value&.to_i
        end

        def process_limit=(value)
          if value
            redis { |it| it.set "#{PREFIX}:process_limit:#{@name}", value }
          else
            redis { |it| it.del "#{PREFIX}:process_limit:#{@name}" }
          end
        end

        def acquire
          Selector.acquire([@name], namespace).size.positive?
        end

        def release
          redis { |it| it.lrem "#{PREFIX}:probed:#{@name}", 1, Selector.uuid }
        end

        def busy
          redis { |it| it.llen "#{PREFIX}:busy:#{@name}" }
        end

        def busy_processes
          redis { |it| it.lrange "#{PREFIX}:busy:#{@name}", 0, -1 }
        end

        def increase_busy
          increase_local_busy
          redis { |it| it.rpush "#{PREFIX}:busy:#{@name}", Selector.uuid }
        end

        def decrease_busy
          decrease_local_busy
          redis { |it| it.lrem "#{PREFIX}:busy:#{@name}", 1, Selector.uuid }
        end

        def probed
          redis { |it| it.llen "#{PREFIX}:probed:#{@name}" }
        end

        def probed_processes
          redis { |it| it.lrange "#{PREFIX}:probed:#{@name}", 0, -1 }
        end

        def pause
          redis { |it| it.set "#{PREFIX}:pause:#{@name}", '1' }
        end

        def pause_for_ms(milliseconds)
          redis { |it| it.psetex "#{PREFIX}:pause:#{@name}", milliseconds, 1 }
        end

        def unpause
          redis { |it| it.del "#{PREFIX}:pause:#{@name}" }
        end

        def paused?
          redis { |it| it.get "#{PREFIX}:pause:#{@name}" } == '1'
        end

        def block
          redis { |it| it.set "#{PREFIX}:block:#{@name}", '1' }
        end

        def block_except(*queues)
          raise ArgumentError if queues.empty?

          redis { |it| it.set "#{PREFIX}:block:#{@name}", queues.join(',') }
        end

        def unblock
          redis { |it| it.del "#{PREFIX}:block:#{@name}" }
        end

        def blocking?
          redis { |it| it.get "#{PREFIX}:block:#{@name}" } == '1'
        end

        def clear_limits
          redis do |it|
            %w[block busy limit pause probed process_limit].each do |key|
              it.del "#{PREFIX}:#{key}:#{@name}"
            end
          end
        end

        def increase_local_busy
          @lock.synchronize { @local_busy += 1 }
        end

        def decrease_local_busy
          @lock.synchronize { @local_busy -= 1 }
        end

        def local_busy?
          @local_busy.positive?
        end

        def explain
          <<-INFO.gsub(/^ {8}/, '')
        Current sidekiq process: #{Selector.uuid}

          All processes:
        #{Monitor.all_processes.join "\n"}

          Stale processes:
        #{Monitor.old_processes.join "\n"}

          Locked queue processes:
        #{probed_processes.sort.join "\n"}

          Busy queue processes:
        #{busy_processes.sort.join "\n"}

          Limit:
        #{limit.inspect}

          Process limit:
        #{process_limit.inspect}

          Blocking:
        #{blocking?}
          INFO
        end

        def remove_locks_except!(processes)
          locked_processes = probed_processes.uniq
          (locked_processes - processes).each do |dead_process|
            remove_lock! dead_process
          end
        end

        def remove_lock!(process)
          redis do |it|
            it.lrem "#{PREFIX}:probed:#{@name}", 0, process
            it.lrem "#{PREFIX}:busy:#{@name}", 0, process
          end
        end

        private

        def redis(&block)
          Sidekiq.redis(&block)
        end

        def namespace
          Sidekiq::LimitFetch::Queues.namespace
        end
      end
    end
  end
end
