require 'spec_helper'

describe 'semaphore' do
  shared_examples_for :semaphore do
    it 'should have no limit by default' do
      subject.limit.should_not be
    end

    it 'should set limit' do
      subject.limit = 4
      subject.limit.should == 4
    end

    it 'should acquire and count active tasks' do
      3.times { subject.acquire }
      subject.busy.should == 3
    end

    it 'should acquire tasks with regard to limit' do
      subject.limit = 4
      6.times { subject.acquire }
      subject.busy.should == 4
    end

    it 'should release active tasks' do
      6.times { subject.acquire }
      3.times { subject.release }
      subject.busy.should == 3
    end

    it 'should pause tasks' do
      3.times { subject.acquire }
      subject.pause
      2.times { subject.acquire }
      subject.busy.should == 3
      2.times { subject.release }
      subject.busy.should == 1
    end

    it 'should unpause tasks' do
      subject.pause
      3.times { subject.acquire }
      subject.continue
      2.times { subject.acquire }
      subject.busy.should == 2
    end
  end

  let(:name) { 'default' }

  context 'local' do
    subject { Sidekiq::LimitFetch::Local::Semaphore.new name }
    it_behaves_like :semaphore
  end

  context 'global' do
    subject { Sidekiq::LimitFetch::Global::Semaphore.new name }
    it_behaves_like :semaphore

    after :each do
      Sidekiq.redis do |it|
        it.del "limit_fetch:limit:#{name}"
        it.del "limit_fetch:busy:#{name}"
        it.del "limit_fetch:pause:#{name}"
      end
    end
  end
end
