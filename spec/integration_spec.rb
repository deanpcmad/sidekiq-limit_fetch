require 'sidekiq/limit_fetch'

describe Sidekiq::LimitFetch do
  before(:each) do
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
    2.times { queues(fetcher).should == %w(queue:example queue:example2) }
    queues(fetcher).should == %w(queue:example2)
  end
end
