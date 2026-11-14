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

      DEFAULT_TRACES_SAMPLE_RATE = 0.05
      DEFAULT_PROFILES_SAMPLE_RATE = 0.0
      # Health checks, assets and websocket/storage plumbing never produce useful traces.
      UNSAMPLED_PATHS = %r{\A/(healthcheck|up|assets|cable|rails/active_storage|packs)(/|\z)}

      def apply_defaults(config, env = ENV)
        config.dsn = Settings.valid(env.fetch('SENTRY_DSN', ''), Settings::DSN_FORMAT).to_s
        release = env.fetch('GIT_REV', '').to_s.strip
        config.release = release unless release.empty?
        environment = Settings.valid(env.fetch('SENTRY_ENVIRONMENT', ''), Settings::ENVIRONMENT_FORMAT)
        config.environment = environment if environment
        config.breadcrumbs_logger = %i[active_support_logger http_logger]
        apply_tracing(config, env)
        config.profiles_sample_rate = sample_rate(env, 'SENTRY_PROFILES_SAMPLE_RATE', DEFAULT_PROFILES_SAMPLE_RATE)
        config.excluded_exceptions += ['SystemExit'] if config.respond_to?(:excluded_exceptions)
        apply_privacy(config)
      end

      # SENTRY_TRACES_SAMPLER: unset or "default" = parent-aware sampler that skips noisy paths,
      # "always" = trace every request (legacy opt-in), "disabled" = plain traces_sample_rate only.
      def apply_tracing(config, env)
        rate = sample_rate(env, 'SENTRY_TRACES_SAMPLE_RATE', DEFAULT_TRACES_SAMPLE_RATE)
        config.traces_sample_rate = rate
        case env.fetch('SENTRY_TRACES_SAMPLER', 'default').to_s.strip
        when 'always' then config.traces_sampler = always_sample
        when 'disabled' then nil
        else config.traces_sampler = path_aware_sampler(rate)
        end
      end

      # A separate client for one platform's settings.
      def apply_platform(config, settings)
        config.dsn = settings.dsn
        config.environment = settings.environment if settings.environment
        config.traces_sample_rate = settings.traces_sample_rate
        config.traces_sampler = path_aware_sampler(settings.traces_sample_rate)
        apply_privacy(config)
      end

      def apply_privacy(config)
        config.send_default_pii = false if config.respond_to?(:send_default_pii=)
        config.before_send = ->(event, _hint) { PrivacyFilter.scrub(event) } if config.respond_to?(:before_send=)
      end

      def sample_rate(env, key, default)
        value = env[key]
        return default if value.nil? || value.to_s.strip.empty?

        rate = Float(value)
        rate.between?(0.0, 1.0) ? rate : default
      rescue ArgumentError, TypeError
        default
      end

      def path_aware_sampler(rate)
        lambda do |context|
          parent = context[:parent_sampled]
          next parent unless parent.nil?

          path = (context[:rack_env] || {}).fetch('PATH_INFO', '').to_s
          path.match?(UNSAMPLED_PATHS) ? 0.0 : rate
        end
      end

      def always_sample
        ->(_context) { true }
      end
    end
  end
end
