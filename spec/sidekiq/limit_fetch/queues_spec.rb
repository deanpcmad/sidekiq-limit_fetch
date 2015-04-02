require 'spec_helper'

RSpec.describe Sidekiq::LimitFetch::Queues do
  subject { described_class.new options }

  let(:queues)   { %w[queue1 queue2] }
  let(:limits)   {{ 'queue1' => 3 }}
  let(:strict)   { true }
  let(:blocking) {}

  let(:options) do
    { queues:   queues,
      limits:   limits,
      strict:   strict,
      blocking: blocking,
      namespace: Sidekiq::LimitFetch::Redis.determine_namespace }
  end

  it 'should acquire queues' do
    subject.acquire
    expect(Sidekiq::Queue['queue1'].probed).to eq 1
    expect(Sidekiq::Queue['queue2'].probed).to eq 1
  end

  it 'should acquire dynamically blocking queues' do
    subject.acquire
    expect(Sidekiq::Queue['queue1'].probed).to eq 1
    expect(Sidekiq::Queue['queue2'].probed).to eq 1

    Sidekiq::Queue['queue1'].block

    subject.acquire
    expect(Sidekiq::Queue['queue1'].probed).to eq 2
    expect(Sidekiq::Queue['queue2'].probed).to eq 1
  end

  it 'should block except given queues' do
    Sidekiq::Queue['queue1'].block_except 'queue2'
    subject.acquire
    expect(Sidekiq::Queue['queue1'].probed).to eq 1
    expect(Sidekiq::Queue['queue2'].probed).to eq 1

    Sidekiq::Queue['queue1'].block_except 'queue404'
    subject.acquire
    expect(Sidekiq::Queue['queue1'].probed).to eq 2
    expect(Sidekiq::Queue['queue2'].probed).to eq 1
  end

  it 'should release queues' do
    subject.acquire
    subject.release_except nil
    expect(Sidekiq::Queue['queue1'].probed).to eq 0
    expect(Sidekiq::Queue['queue2'].probed).to eq 0
  end

  it 'should release queues except selected' do
    subject.acquire
    subject.release_except 'queue:queue1'
    expect(Sidekiq::Queue['queue1'].probed).to eq 1
    expect(Sidekiq::Queue['queue2'].probed).to eq 0
  end

  it 'should release when no queues was acquired' do
    queues.each {|name| Sidekiq::Queue[name].pause }
    subject.acquire
    expect { subject.release_except nil }.not_to raise_exception
  end

  context 'blocking' do
    let(:blocking) { %w(queue1) }

    it 'should acquire blocking queues' do
      3.times { subject.acquire }
      expect(Sidekiq::Queue['queue1'].probed).to eq 3
      expect(Sidekiq::Queue['queue2'].probed).to eq 1
    end
  end

  it 'should set limits' do
    subject
    expect(Sidekiq::Queue['queue1'].limit).to eq 3
    expect(Sidekiq::Queue['queue2'].limit).not_to be
  end

  context 'without strict flag' do
    let(:strict) { false }

    it 'should retrieve weighted queues' do
      expect(subject.ordered_queues).to match_array(%w(queue1 queue2))
    end
  end

  it 'with strict flag should retrieve strictly ordered queues' do
    expect(subject.ordered_queues).to eq %w(queue1 queue2)
  end
end
