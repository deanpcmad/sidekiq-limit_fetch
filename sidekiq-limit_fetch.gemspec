Gem::Specification.new do |gem|
  gem.name          = 'sidekiq-limit_fetch'
  gem.version       = '3.4.0'
  gem.license       = 'MIT'
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

  gem.add_dependency 'sidekiq', '>= 4'
  gem.add_development_dependency 'appraisal'
  gem.add_development_dependency 'redis-namespace', '~> 1.5', '>= 1.5.2'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'rake'
end
