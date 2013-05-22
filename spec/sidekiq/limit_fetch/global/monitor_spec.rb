require 'spec_helper'

describe Sidekiq::LimitFetch::Global::Monitor do
  let(:monitor) { described_class.start! ttl, timeout }
  let(:ttl) { 1 }
  let(:queue) { Sidekiq::Queue[name] }
  let(:name) { 'default' }

  before :each do
    monitor
  end

  after :each do
    monitor.kill
  end

  context 'old locks' do
    let(:timeout) { 0.5 }

    it 'should remove invalidated old locks' do
      2.times { queue.acquire }
      sleep 2*ttl
      queue.busy.should == 2

      described_class.stub :update_heartbeat
      sleep 2*ttl
      queue.busy.should == 0
    end
  end
end
