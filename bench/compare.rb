require 'benchmark'
require 'sidekiq/cli'
require 'sidekiq/api'

total       = (ARGV.shift || 50).to_i
concurrency = ARGV.shift || 1
limit       = ARGV.shift

if limit
  limit = nil if limit == 'nil'

  $:.unshift File.expand_path '../lib'
  require 'sidekiq-limit_fetch'
  Sidekiq::Queue['inline'].limit = limit
  Sidekiq.redis {|it| it.del 'limit_fetch:probed:inline' }
  Sidekiq::LimitFetch::Queues.send(:define_method, :set) {|*| }
end

Sidekiq::Queue.new('inline').clear

class FastJob
  include Sidekiq::Worker
  sidekiq_options queue: :inline

  def perform(i)
    puts "job N#{i} is finished"
  end
end

class FinishJob
  include Sidekiq::Worker
  sidekiq_options queue: :inline

  def perform
    Process.kill 'INT', 0
  end
end

total.times {|i| FastJob.perform_async i+1 }
FinishJob.perform_async

Sidekiq::CLI.instance.tap do |cli|
  %w(validate! boot_system).each {|stub| cli.define_singleton_method(stub) {}}
  cli.parse ['-q inline', '-q other', "-c #{concurrency}"]

  puts Benchmark.measure {
    begin
      cli.run
    rescue Exception
    end
  }
end
