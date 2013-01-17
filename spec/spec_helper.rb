require 'sidekiq/limit_fetch'

RSpec.configure do |config|
  config.before :each do
    Sidekiq::Queue.instance_variable_set :@instances, {}
  end
end
