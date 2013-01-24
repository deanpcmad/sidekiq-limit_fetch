require 'spec_helper'

describe Sidekiq::LimitFetch::Global::Monitor do
  let(:global) { true }
  let(:monitor) { described_class.start! ttl, timeout }
  let(:ttl) { 2 }
  let(:queue) { Sidekiq::Queue[name] }
  let(:name) { 'default' }

  before :each do
    monitor
  end

  after :each do
    monitor.kill
  end

  context 'old locks' do
    let(:timeout) { 100 }

    it 'should remove invalidated old locks' do
      2.times { queue.acquire }
      described_class.send(:invalidate_old_processors)
      queue.busy.should == 2
      sleep 4
      described_class.send(:invalidate_old_processors)
      queue.busy.should == 0
    end
  end
end
