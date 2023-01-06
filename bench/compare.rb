# frozen_string_literal: true

require 'benchmark'
require 'sidekiq/cli'
require 'sidekiq/api'

total       = (ARGV.shift || 50).to_i
concurrency = ARGV.shift || 1
limit       = ARGV.shift

if limit
  limit = nil if limit == 'nil'

  $LOAD_PATH.unshift File.expand_path '../lib'
  require 'sidekiq-limit_fetch'
  Sidekiq::Queue['inline'].limit = limit
  Sidekiq.redis { |it| it.del 'limit_fetch:probed:inline' }
  Sidekiq::LimitFetch::Queues.send(:define_method, :set) { |*| } # rubocop:disable Lint/EmptyBlock
end

Sidekiq::Queue.new('inline').clear

class FastJob
  include Sidekiq::Worker
  sidekiq_options queue: :inline

  def perform(index)
    puts "job N#{index} is finished"
  end
end

class FinishJob
  include Sidekiq::Worker
  sidekiq_options queue: :inline

  def perform
    Process.kill 'INT', 0
  end
end

total.times { |i| FastJob.perform_async i + 1 }
FinishJob.perform_async

Sidekiq::CLI.instance.tap do |cli|
  %w[validate! boot_system].each { |stub| cli.define_singleton_method(stub) {} } # rubocop:disable Lint/EmptyBlock
  cli.parse ['-q inline', '-q other', "-c #{concurrency}"]

  # rubocop:disable Lint/RescueException
  # rubocop:disable Lint/SuppressedException
  puts Benchmark.measure do
    cli.run
  rescue Exception
  end
  # rubocop:enable Lint/SuppressedException
  # rubocop:enable Lint/RescueException
end
