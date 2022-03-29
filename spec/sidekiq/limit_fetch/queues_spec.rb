RSpec.describe Sidekiq::LimitFetch::Queues do
  let(:queues)         { %w[queue1 queue2] }
  let(:limits)         {{ 'queue1' => 3 }}
  let(:strict)         { true }
  let(:blocking)       {}
  let(:process_limits) {{ 'queue2' => 3 }}

  let(:options) do
    { queues:   queues,
      limits:   limits,
      strict:   strict,
      blocking: blocking,
      process_limits: process_limits }
  end

  before { subject.start options }

  def in_thread(&block)
    thr = Thread.new(&block)
    thr.join
  end

  it 'should acquire queues' do
    in_thread { subject.acquire }
    expect(Sidekiq::Queue['queue1'].probed).to eq 1
    expect(Sidekiq::Queue['queue2'].probed).to eq 1
  end

  it 'should acquire dynamically blocking queues' do
    in_thread { subject.acquire }
    expect(Sidekiq::Queue['queue1'].probed).to eq 1
    expect(Sidekiq::Queue['queue2'].probed).to eq 1

    Sidekiq::Queue['queue1'].block

    in_thread { subject.acquire }
    expect(Sidekiq::Queue['queue1'].probed).to eq 2
    expect(Sidekiq::Queue['queue2'].probed).to eq 1
  end

  it 'should block except given queues' do
    Sidekiq::Queue['queue1'].block_except 'queue2'
    in_thread { subject.acquire }
    expect(Sidekiq::Queue['queue1'].probed).to eq 1
    expect(Sidekiq::Queue['queue2'].probed).to eq 1

    Sidekiq::Queue['queue1'].block_except 'queue404'
    in_thread { subject.acquire }
    expect(Sidekiq::Queue['queue1'].probed).to eq 2
    expect(Sidekiq::Queue['queue2'].probed).to eq 1
  end

  it 'should release queues' do
    in_thread {
      subject.acquire
      subject.release_except nil
    }
    expect(Sidekiq::Queue['queue1'].probed).to eq 0
    expect(Sidekiq::Queue['queue2'].probed).to eq 0
  end

  it 'should release queues except selected' do
    in_thread {
      subject.acquire
      subject.release_except 'queue:queue1'
    }
    expect(Sidekiq::Queue['queue1'].probed).to eq 1
    expect(Sidekiq::Queue['queue2'].probed).to eq 0
  end

  it 'should release when no queues was acquired' do
    queues.each {|name| Sidekiq::Queue[name].pause }
    in_thread {
      subject.acquire
      expect { subject.release_except nil }.not_to raise_exception
    }
  end

  context 'blocking' do
    let(:blocking) { %w(queue1) }

    it 'should acquire blocking queues' do
      3.times { in_thread { subject.acquire  } }
      expect(Sidekiq::Queue['queue1'].probed).to eq 3
      expect(Sidekiq::Queue['queue2'].probed).to eq 1
    end
  end

  it 'should set limits' do
    subject
    expect(Sidekiq::Queue['queue1'].limit).to eq 3
    expect(Sidekiq::Queue['queue2'].limit).not_to be
  end

  it 'should set process_limits' do
    subject
    expect(Sidekiq::Queue['queue2'].process_limit).to eq 3
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
