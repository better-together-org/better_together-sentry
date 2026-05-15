# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

require 'better_together/sentry/version'

Gem::Specification.new do |spec|
  spec.name          = 'better_together-sentry'
  spec.version       = BetterTogether::Sentry::VERSION
  spec.authors       = ['Robert JJ Smith']
  spec.email         = ['rob@bettertogethersolutions.com']
  spec.summary       = 'Sentry adapter gem for Better Together subsystem adapters.'
  spec.description   = 'Registers Sentry error-reporting and browser head-tag providers for Better Together without adding Sentry ownership to CE itself.'
  spec.homepage      = 'https://github.com/better-together-org'
  spec.license       = 'LGPL-3.0-or-later'
  spec.required_ruby_version = '>= 3.2'

  spec.files = Dir['lib/**/*', 'README.md', 'LICENSE*']
  spec.require_paths = ['lib']

  spec.add_dependency 'better_together', '>= 0.11.0'
  spec.add_dependency 'sentry-rails'
end
