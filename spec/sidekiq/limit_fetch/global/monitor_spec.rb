RSpec.describe Sidekiq::LimitFetch::Global::Monitor do
  let(:monitor) { described_class.start! ttl, timeout }
  let(:ttl) { 1 }
  let(:queue) { Sidekiq::Queue[name] }
  let(:name) { 'default' }

  before { monitor }
  after { monitor.kill }

  context 'old locks' do
    let(:timeout) { 0.5 }

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
end
