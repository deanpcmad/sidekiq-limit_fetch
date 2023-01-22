# frozen_string_literal: true

require 'English'
Gem::Specification.new do |gem|
  gem.name          = 'sidekiq-limit_fetch'
  gem.version       = '4.4.1'
  gem.license       = 'MIT'
  gem.authors       = ['Dean Perry']
  gem.email         = 'dean@deanpcmad.com'
  gem.summary       = 'Sidekiq strategy to support queue limits'
  gem.homepage      = 'https://github.com/deanpcmad/sidekiq-limit_fetch'
  gem.description   = 'Sidekiq strategy to restrict number of workers which are able to run specified ' \
                      'queues simultaneously.'

  gem.metadata['homepage_uri'] = gem.homepage
  gem.metadata['source_code_uri'] = 'https://github.com/deanpcmad/sidekiq-limit_fetch'
  gem.metadata['changelog_uri'] = 'https://github.com/deanpcmad/sidekiq-limit_fetch/blob/master/CHANGELOG.md'
  gem.metadata['rubygems_mfa_required'] = 'true'

  gem.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  gem.require_paths = %w[lib]

  gem.required_ruby_version = '>= 2.7.0'

  gem.add_dependency 'sidekiq', '>= 6'
  gem.add_development_dependency 'appraisal'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'redis-namespace', '~> 1.5', '>= 1.5.2'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'rubocop'
  gem.add_development_dependency 'simplecov'
end
