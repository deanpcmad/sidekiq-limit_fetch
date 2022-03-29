Thread.abort_on_exception = true

RSpec.describe Sidekiq::LimitFetch do
  let(:options) {{ queues: queues, limits: limits }}
  let(:queues) { %w(queue1 queue1 queue2 queue2) }
  let(:limits) {{ 'queue1' => 1, 'queue2' => 2 }}

  before do
    subject::Queues.start options

    Sidekiq.redis do |it|
      it.del 'queue:queue1'
      it.lpush 'queue:queue1', 'task1'
      it.lpush 'queue:queue1', 'task2'
      it.expire 'queue:queue1', 30
    end
  end

  it 'should acquire lock on queue for execution' do
    work = subject.retrieve_work
    expect(work.queue_name).to eq 'queue1'
    expect(work.job).to eq 'task1'

    expect(Sidekiq::Queue['queue1'].busy).to eq 1
    expect(Sidekiq::Queue['queue2'].busy).to eq 0

    expect(subject.retrieve_work).not_to be
    work.requeue

    expect(Sidekiq::Queue['queue1'].busy).to eq 0
    expect(Sidekiq::Queue['queue2'].busy).to eq 0

    work = subject.retrieve_work
    expect(work.job).to eq 'task1'

    expect(Sidekiq::Queue['queue1'].busy).to eq 1
    expect(Sidekiq::Queue['queue2'].busy).to eq 0

    expect(subject.retrieve_work).not_to be
    work.acknowledge

    expect(Sidekiq::Queue['queue1'].busy).to eq 0
    expect(Sidekiq::Queue['queue2'].busy).to eq 0

    work = subject.retrieve_work
    expect(work.job).to eq 'task2'
  end
end
