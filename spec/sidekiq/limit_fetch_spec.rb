require 'spec_helper'

describe Sidekiq::LimitFetch do
  before :each do
    Sidekiq.redis do |it|
      it.del 'queue:queue1'
      it.lpush 'queue:queue1', 'task1'
      it.lpush 'queue:queue1', 'task2'
      it.expire 'queue:queue1', 30
    end
  end

  subject { described_class.new options }
  let(:options) {{ queues: queues, limits: limits }}
  let(:queues) { %w(queue1 queue1 queue2 queue2) }
  let(:limits) {{ 'queue1' => 1, 'queue2' => 2 }}

  it 'should acquire lock on queue for execution' do
    work = subject.retrieve_work
    work.queue_name.should == 'queue1'
    work.message.should == 'task1'

    Sidekiq::Queue['queue1'].busy.should == 1
    Sidekiq::Queue['queue2'].busy.should == 0

    subject.retrieve_work.should_not be
    work.requeue

    Sidekiq::Queue['queue1'].busy.should == 0
    Sidekiq::Queue['queue2'].busy.should == 0

    work = subject.retrieve_work
    work.message.should == 'task1'

    Sidekiq::Queue['queue1'].busy.should == 1
    Sidekiq::Queue['queue2'].busy.should == 0

    subject.retrieve_work.should_not be
    work.acknowledge

    Sidekiq::Queue['queue1'].busy.should == 0
    Sidekiq::Queue['queue2'].busy.should == 0

    work = subject.retrieve_work
    work.message.should == 'task2'
  end
end
