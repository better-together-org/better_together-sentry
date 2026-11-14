# frozen_string_literal: true

require 'better_together'
require 'sentry-ruby'
require 'better_together/sentry/settings'
require 'better_together/sentry/configuration'
require 'better_together/sentry/csp_sources'
require 'better_together/sentry/version'
require 'better_together/sentry/head_tags'
require 'better_together/sentry/consent_gate'
require 'better_together/sentry/privacy_filter'
require 'better_together/sentry/policy'
require 'better_together/sentry/reporter'
require 'better_together/sentry/railtie' if defined?(Rails::Railtie)

module BetterTogether
  module Sentry
    module_function

    def register!
      Settings.register!
      Policy.register!
      return unless BetterTogether.respond_to?(:register_head_tag_provider)
      return unless BetterTogether.respond_to?(:register_content_security_policy_sources)

      BetterTogether.register_head_tag_provider(:sentry) do |view_context|
        HeadTags.render(view_context)
      end
      register_csp_sources
    end

    # CE's registered CSP sources are global, not per platform, so only the origins implied by the
    # process environment (the host platform) can be registered here. A platform with its own DSN or
    # client key needs those origins in its platform CSP settings until CE supports platform-scoped
    # registration. CspSources.origins_for(platform) computes the exact list for that.
    def register_csp_sources
      env = CspSources.origins_for(nil)
      BetterTogether.register_content_security_policy_sources(:script_src, env[:script_src])
      BetterTogether.register_content_security_policy_sources(:connect_src, env[:connect_src])
    end
  end
end

BetterTogether::Sentry.register!
