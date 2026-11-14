# frozen_string_literal: true

# These specs exercise the gem against Community Engine's cookie policy and consent registries. They
# need a Community Engine checkout that has them (feat/user-consent-preferences or later); point
# BETTER_TOGETHER_CE_LIB at its lib directory, or run inside a bundle that provides better_together.
# Without them the suite skips instead of failing.
ce_lib = ENV.fetch('BETTER_TOGETHER_CE_LIB', nil)
$LOAD_PATH.unshift(ce_lib) if ce_lib && !ce_lib.empty?
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

begin
  require 'active_support'
  require 'active_support/all'
  require 'i18n'
  require 'better_together/platform_settings_registry'
  require 'better_together/cookie_policy'
  require 'better_together/consent'
  require 'better_together/cookie_policy/rspec'
  CE_CONSENT_API = true
rescue LoadError
  CE_CONSENT_API = false
end

if CE_CONSENT_API
  I18n.enforce_available_locales = false
  require 'better_together/sentry/settings'
  require 'better_together/sentry/policy'
end

RSpec.configure do |config|
  config.before { skip 'Community Engine consent API not available (set BETTER_TOGETHER_CE_LIB)' unless CE_CONSENT_API }
  config.disable_monkey_patching!
end
