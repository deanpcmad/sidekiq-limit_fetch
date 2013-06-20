module Sidekiq::LimitFetch::Singleton
  def self.extended(klass)
    klass.instance_variable_set :@instances, {}
  end

  def new(*args)
    @instances[args] ||= super
  end

  alias [] new

  def instances
    @instances.values
  end
end
