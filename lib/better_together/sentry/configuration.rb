# frozen_string_literal: true

require 'better_together/sentry/settings'
require 'better_together/sentry/privacy_filter'

module BetterTogether
  module Sentry
    # Owns default Sentry runtime bootstrap for host apps that include this gem. The process-wide
    # Sentry is initialised from the environment (the host platform's values); other platforms with
    # their own DSN are served by Reporter through separate clients.
    module Configuration
      module_function

      def bootstrap!(env = ENV)
        return unless defined?(::Sentry)
        return if ::Sentry.initialized?

        dsn = Settings.valid(env.fetch('SENTRY_DSN', ''), Settings::DSN_FORMAT)
        return unless dsn

        ::Sentry.init do |config|
          apply_defaults(config, env)
        end
      end

      def apply_defaults(config, env = ENV)
        config.dsn = Settings.valid(env.fetch('SENTRY_DSN', ''), Settings::DSN_FORMAT).to_s
        config.release = env.fetch('GIT_REV', '').to_s
        environment = Settings.valid(env.fetch('SENTRY_ENVIRONMENT', ''), Settings::ENVIRONMENT_FORMAT)
        config.environment = environment if environment
        config.breadcrumbs_logger = %i[active_support_logger http_logger]
        config.traces_sample_rate = sample_rate(env, 'SENTRY_TRACES_SAMPLE_RATE', 1.0)
        config.traces_sampler = always_sample if env.fetch('SENTRY_TRACES_SAMPLER', 'always') == 'always'
        config.profiles_sample_rate = sample_rate(env, 'SENTRY_PROFILES_SAMPLE_RATE', 1.0)
        apply_privacy(config)
      end

      # A separate client for one platform's settings.
      def apply_platform(config, settings)
        config.dsn = settings.dsn
        config.environment = settings.environment if settings.environment
        config.traces_sample_rate = settings.traces_sample_rate
        apply_privacy(config)
      end

      def apply_privacy(config)
        config.send_default_pii = false if config.respond_to?(:send_default_pii=)
        config.before_send = ->(event, _hint) { PrivacyFilter.scrub(event) } if config.respond_to?(:before_send=)
      end

      def sample_rate(env, key, default)
        value = env[key]
        return default if value.nil? || value.to_s.strip.empty?

        Float(value)
      rescue ArgumentError, TypeError
        default
      end

      def always_sample
        ->(_context) { true }
      end
    end
  end
end
