require 'spec_helper'

describe Sidekiq::LimitFetch do
  before :each do
    Sidekiq.redis do |it|
      it.del 'queue:example1'
      it.rpush 'queue:example1', 'task'
      it.expire 'queue:example1', 30
    end
  end

  def queues(fetcher)
    fetcher.available_queues.map(&:full_name)
  end

  def new_fetcher(options={})
    described_class.new options.merge queues: %w(example1 example1 example2 example2)
  end

  it 'should retrieve weighted queues' do
    fetcher = new_fetcher
    queues(fetcher).should =~ %w(queue:example1 queue:example2)
  end

  it 'should retrieve strictly ordered queues' do
    fetcher = new_fetcher strict: true
    queues(fetcher).should == %w(queue:example1 queue:example2)
  end

  it 'should retrieve only available queues' do
    fetcher = new_fetcher strict: true, limits: { 'example1' => 2 }
    queues = -> { fetcher.available_queues }

    queues1 = queues.call
    queues2 = queues.call
    queues1.should have(2).items
    queues2.should have(2).items
    queues.call.should have(1).items

    queues1.each(&:release)
    queues.call.should have(2).items
    queues.call.should have(1).items

    queues2.each(&:release)
    queues.call.should have(2).items
    queues.call.should have(1).items
  end

  it 'should acquire lock on queue for excecution' do
    fetcher = new_fetcher limits: { 'example1' => 1, 'example2' => 1 }
    work = fetcher.retrieve_work
    work.message.should == 'task'
    work.queue.should == 'queue:example1'
    work.queue_name.should == 'example1'

    queues = fetcher.available_queues
    queues.should have(1).item
    queues.each(&:release)

    work.requeue
    work = fetcher.retrieve_work
    work.message.should == 'task'
    work.acknowledge

    fetcher.available_queues.should have(2).items
  end

  it 'should set queue limits on the fly' do
    Sidekiq::Queue['example1'].limit = 1
    Sidekiq::Queue['example2'].limit = 2

    fetcher = new_fetcher

    fetcher.available_queues.should have(2).item
    fetcher.available_queues.should have(1).item
    fetcher.available_queues.should have(0).item

    Sidekiq::Queue['example1'].limit = 2
    fetcher.available_queues.should have(1).item
  end
end
