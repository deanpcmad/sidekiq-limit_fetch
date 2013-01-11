Sidekiq::LimitFetch::UnitOfWork = Struct.new :queue_wrapper, :message do
  extend Forwardable

  def_delegator :queue_wrapper, :full_name, :queue
  def_delegator :queue_wrapper, :name, :queue_name
  def_delegator :queue_wrapper, :release

  def acknowledge
    release
  end

  def requeue
    release
    Sidekiq.redis {|it| it.rpush queue, message }
  end
end
