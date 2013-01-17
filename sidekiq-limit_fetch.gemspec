Gem::Specification.new do |gem|
  gem.name          = 'sidekiq-limit_fetch'
  gem.version       = '0.5'
  gem.authors       = 'brainopia'
  gem.email         = 'brainopia@evilmartians.com'
  gem.summary       = 'Sidekiq strategy to support queue limits'
  gem.homepage      = 'https://github.com/brainopia/sidekiq-limit_fetch'
  gem.description   = <<-DESCRIPTION
    Sidekiq strategy to restrict number of workers
    which are able to run specified queues simultaneously.
  DESCRIPTION

  gem.files         = `git ls-files`.split($/)
  gem.test_files    = gem.files.grep %r{^spec/}
  gem.require_paths = %w(lib)

  gem.add_dependency 'sidekiq', '>= 2.6.3'
  gem.add_development_dependency 'rspec'
end
