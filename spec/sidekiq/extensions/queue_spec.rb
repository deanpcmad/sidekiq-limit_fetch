# frozen_string_literal: true

RSpec.describe Sidekiq::Queue do
  context 'singleton' do
    shared_examples :constructor do
      it 'with default name' do
        new_object = -> { described_class.send constructor }
        expect(new_object.call).to eq new_object.call
      end

      it 'with given name' do
        new_object = ->(name) { described_class.send constructor, name }
        expect(new_object.call('name')).to eq new_object.call('name')
      end
    end

    context '.new' do
      let(:constructor) { :new }
      it_behaves_like :constructor
    end

    context '.[]' do
      let(:constructor) { :[] }
      it_behaves_like :constructor
    end

    context '#lock' do
      let(:name) { 'example' }
      let(:queue) { Sidekiq::Queue[name] }

      it 'should be available' do
        expect(queue.acquire).to be
      end

      it 'should be pausable' do
        queue.pause
        expect(queue.acquire).not_to be
      end

      it 'should be continuable' do
        queue.pause
        queue.unpause
        expect(queue.acquire).to be
      end

      it 'should be limitable' do
        queue.limit = 1
        expect(queue.acquire).to be
        expect(queue.acquire).not_to be
      end

      it 'should be resizable' do
        queue.limit = 0
        expect(queue.acquire).not_to be
        queue.limit = nil
        expect(queue.acquire).to be
      end

      it 'should be countable' do
        queue.limit = 3
        5.times { queue.acquire }
        expect(queue.probed).to eq 3
      end

      it 'should be releasable' do
        queue.acquire
        expect(queue.probed).to eq 1
        queue.release
        expect(queue.probed).to eq 0
      end

      it 'should tell if paused' do
        expect(queue).not_to be_paused
        queue.pause
        expect(queue).to be_paused
        queue.unpause
        expect(queue).not_to be_paused
      end

      it 'should tell if blocking' do
        expect(queue).not_to be_blocking
        queue.block
        expect(queue).to be_blocking
        queue.unblock
        expect(queue).not_to be_blocking
      end

      it 'should be marked as changed' do
        queue = Sidekiq::Queue["uniq_#{name}"]
        expect(queue).not_to be_limit_changed
        queue.limit = 3
        expect(queue).to be_limit_changed
      end
    end
  end
end
