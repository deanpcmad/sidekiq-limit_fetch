require 'sidekiq/limit_fetch'

describe Sidekiq::LimitFetch do
  before :each do
    Sidekiq.redis do |it|
      it.del 'queue:example'
      it.rpush 'queue:example', 'task'
      it.expire 'queue:example', 30
    end
  end

  def queues(fetcher)
    fetcher.available_queues.map(&:full_name)
  end

  def new_fetcher(options={})
    described_class.new options.merge queues: %w(example example example2 example2)
  end

  it 'should retrieve weighted queues' do
    fetcher = new_fetcher
    queues(fetcher).should =~ %w(queue:example queue:example2)
  end

  it 'should retrieve strictly ordered queues' do
    fetcher = new_fetcher strict: true
    queues(fetcher).should == %w(queue:example queue:example2)
  end

  it 'should retrieve limited queues' do
    fetcher = new_fetcher strict: true, limits: { 'example' => 2 }
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
    fetcher = new_fetcher limits: { 'example' => 1, 'example2' => 1 }
    work = fetcher.retrieve_work
    work.message.should == 'task'
    work.queue.should == 'queue:example'
    work.queue_name.should == 'example'

    queues = fetcher.available_queues
    queues.should have(1).item
    queues.each(&:release)

    work.requeue
    work = fetcher.retrieve_work
    work.message.should == 'task'
    work.acknowledge

    fetcher.available_queues.should have(2).items
  end
end
