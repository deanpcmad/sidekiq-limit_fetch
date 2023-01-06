# frozen_string_literal: true

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
      sleep ttl * 2
      expect(queue.probed).to eq 2

      allow(described_class).to receive(:update_heartbeat)
      sleep ttl * 2
      expect(queue.probed).to eq 0
    end

    it 'should remove invalid locks' do
      2.times { queue.acquire }
      allow(described_class).to receive(:update_heartbeat)
      Sidekiq.redis do |it|
        it.del Sidekiq::LimitFetch::Global::Monitor::PROCESS_SET
      end
      sleep ttl * 2
      expect(queue.probed).to eq 0
    end
  end

  context 'dynamic queue' do
    let(:limits) do
      {
        'queue1' => 3,
        'queue2' => 3
      }
    end
    let(:queues) { %w[queue1 queue2] }
    let(:queue) { Sidekiq::LimitFetch::Queues }

    let(:config) { Sidekiq::Config.new(options) }
    let(:capsule) do
      config.capsule('default') do |cap|
        cap.concurrency = 1
        cap.queues = config[:queues]
      end
    end

    let(:capsule_or_options) do
      Sidekiq::LimitFetch.post_7? ? capsule : options
    end

    context 'without excluded queue' do
      let(:options) do
        {
          limits: limits,
          queues: queues,
          dynamic: true
        }
      end

      it 'should add dynamic queue' do
        queue.start(capsule_or_options)
        monitor

        expect(queue.instance_variable_get(:@queues)).not_to include('queue3')

        Sidekiq.redis do |it|
          it.sadd 'queues', 'queue3'
        end

        sleep ttl * 2
        expect(queue.instance_variable_get(:@queues)).to include('queue3')

        Sidekiq.redis do |it|
          it.srem 'queues', 'queue3'
        end
      end
    end

    context 'with excluded queue' do
      let(:options) do
        {
          limits: limits,
          queues: queues,
          dynamic: { exclude: ['queue4'] }
        }
      end

      it 'should exclude excluded dynamic queue' do
        queue.start(capsule_or_options)
        monitor

        expect(queue.instance_variable_get(:@queues)).not_to include('queue4')

        Sidekiq.redis do |it|
          it.sadd 'queues', 'queue4'
        end

        sleep ttl * 2
        expect(queue.instance_variable_get(:@queues)).not_to include('queue4')

        Sidekiq.redis do |it|
          it.srem 'queues', 'queue4'
        end
      end
    end
  end
end
