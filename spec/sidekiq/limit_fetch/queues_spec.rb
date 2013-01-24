require 'spec_helper'

describe Sidekiq::LimitFetch::Queues do
  subject { described_class.new options }

  let(:queues) { %w[queue1 queue2] }
  let(:limits) {{ 'queue1' => 3 }}
  let(:strict) { true }
  let(:global) { false }

  let(:options) do
    { queues: queues, limits: limits, strict: strict, global: global }
  end

  after(:each ) do
    Thread.current[:available_queues] = nil
  end

  shared_examples_for :selector do
    it 'should acquire queues' do
      subject.acquire
      Sidekiq::Queue['queue1'].busy.should == 1
      Sidekiq::Queue['queue2'].busy.should == 1
    end

    it 'should release queues' do
      subject.acquire
      subject.release_except nil
      Sidekiq::Queue['queue1'].busy.should == 0
      Sidekiq::Queue['queue2'].busy.should == 0
    end

    it 'should release queues except selected' do
      subject.acquire
      subject.release_except 'queue:queue1'
      Sidekiq::Queue['queue1'].busy.should == 1
      Sidekiq::Queue['queue2'].busy.should == 0
    end
  end
  
  context 'without global flag' do
    it_should_behave_like :selector

    it 'without global flag should be local' do
      subject.selector.should == Sidekiq::LimitFetch::Local::Selector
    end
  end

  context 'with global flag' do
    let(:global) { true }
    it_should_behave_like :selector

    it 'should use global selector' do
      subject.selector.should == Sidekiq::LimitFetch::Global::Selector
    end
  end

  it 'should set limits' do
    subject
    Sidekiq::Queue['queue1'].limit.should == 3
    Sidekiq::Queue['queue2'].limit.should_not be
  end

  context 'without strict flag' do
    let(:strict) { false }

    it 'should retrieve weighted queues' do
      subject.ordered_queues.should =~ %w(queue1 queue2)
    end
  end

  it 'with strict flag should retrieve strictly ordered queues' do
    subject.ordered_queues.should == %w(queue1 queue2)
  end
end
