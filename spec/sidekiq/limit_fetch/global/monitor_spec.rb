RSpec.describe Sidekiq::LimitFetch::Global::Monitor do
  let(:monitor) { described_class.start! ttl, timeout }
  let(:ttl) { 1 }
  let(:queue) { Sidekiq::Queue[name] }
  let(:name) { 'default' }
  let(:timeout) { 0.5 }

  after { monitor.kill }

  context 'old locks' do
    before { monitor }

    it 'should remove invalidated old locks' do
      2.times { queue.acquire }
      sleep 2*ttl
      expect(queue.probed).to eq 2

      allow(described_class).to receive(:update_heartbeat)
      sleep 2*ttl
      expect(queue.probed).to eq 0
    end

    it 'should remove invalid locks' do
      2.times { queue.acquire }
      allow(described_class).to receive(:update_heartbeat)
      Sidekiq.redis do |it|
        it.del Sidekiq::LimitFetch::Global::Monitor::PROCESS_SET
      end
      sleep 2*ttl
      expect(queue.probed).to eq 0
    end

  end

  context 'dynamic queue' do
    let(:limits) do
      {
        'queue1' => 3,
        'queue2' => 3,
      }
    end
    let(:queues) { %w[queue1 queue2] }
    let(:queue) { Sidekiq::LimitFetch::Queues }
    let(:options) do
      {
        limits: limits,
        queues: queues,
      }
    end

    it 'should add dynamic queue' do
      queue.start(options.merge({ dynamic: true }))
      monitor

      expect(queue.instance_variable_get(:@queues)).not_to include('queue3')

      Sidekiq.redis do |it|
        it.sadd 'queues', 'queue3'
      end

      sleep 2*ttl
      expect(queue.instance_variable_get(:@queues)).to include('queue3')

      Sidekiq.redis do |it|
        it.srem 'queues', 'queue3'
      end
    end

    it 'should exclude excluded dynamic queue' do
      queue.start(options.merge({ dynamic: { exclude: ['queue4'] } }))
      monitor

      expect(queue.instance_variable_get(:@queues)).not_to include('queue4')

      Sidekiq.redis do |it|
        it.sadd 'queues', 'queue4'
      end

      sleep 2*ttl
      expect(queue.instance_variable_get(:@queues)).not_to include('queue4')

      Sidekiq.redis do |it|
        it.srem 'queues', 'queue4'
      end
    end
  end
end
