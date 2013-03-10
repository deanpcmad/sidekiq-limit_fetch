require 'spec_helper'

describe Sidekiq::LimitFetch do
  before :each do
    Sidekiq.redis do |it|
      it.del 'queue:queue1'
      it.rpush 'queue:queue1', 'task1'
      it.rpush 'queue:queue1', 'task2'
      it.expire 'queue:queue1', 30
    end
  end

  subject { described_class.new options }
  let(:options) {{ queues: queues, limits: limits, global: global }}
  let(:queues) { %w(queue1 queue1 queue2 queue2) }
  let(:limits) {{ 'queue1' => 1, 'queue2' => 2 }}

  shared_examples_for :strategy do
    it 'should acquire lock on queue for execution' do
      work = subject.retrieve_work
      work.queue_name.should == 'queue1'
      work.message.should == 'task1'

      subject.retrieve_work.should_not be
      work.requeue

      work = subject.retrieve_work
      work.message.should == 'task2'

      subject.retrieve_work.should_not be
      work.acknowledge

      work = subject.retrieve_work
      work.message.should == 'task1'
    end
  end

  context 'global' do
    let(:global) { true }
    it_behaves_like :strategy
  end

  context 'local' do
    let(:global) { false }
    it_behaves_like :strategy
  end
end
