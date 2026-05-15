# frozen_string_literal: true

require 'better_together'
require 'sentry-ruby'
require 'better_together/sentry/csp_sources'
require 'better_together/sentry/version'
require 'better_together/sentry/head_tags'
require 'better_together/sentry/reporter'
require 'better_together/sentry/railtie' if defined?(Rails::Railtie)

module BetterTogether
  module Sentry
    module_function

    def register!
      return unless BetterTogether.respond_to?(:register_head_tag_provider)
      return unless BetterTogether.respond_to?(:register_content_security_policy_sources)

      BetterTogether.register_head_tag_provider(:sentry) do |view_context|
        HeadTags.render(view_context)
      end
      BetterTogether.register_content_security_policy_sources(:script_src, 'https://js-de.sentry-cdn.com')
      BetterTogether.register_content_security_policy_sources(:connect_src, CspSources.connect_sources)
    end
  end
end

BetterTogether::Sentry.register!
