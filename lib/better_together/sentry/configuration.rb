# frozen_string_literal: true

module BetterTogether
  module Sentry
    # Owns default Sentry runtime bootstrap for host apps that include this gem.
    module Configuration
      module_function

      def bootstrap!(env = ENV)
        return unless defined?(::Sentry)
        return if ::Sentry.initialized?

        dsn = env.fetch('SENTRY_DSN', '').to_s.strip
        return if dsn.empty?

        ::Sentry.init do |config|
          apply_defaults(config, env)
        end
      end

      def apply_defaults(config, env = ENV)
        config.dsn = env.fetch('SENTRY_DSN', '').to_s
        config.release = env.fetch('GIT_REV', '').to_s
        config.breadcrumbs_logger = %i[active_support_logger http_logger]
        config.traces_sample_rate = sample_rate(env, 'SENTRY_TRACES_SAMPLE_RATE', 1.0)
        config.traces_sampler = always_sample if env.fetch('SENTRY_TRACES_SAMPLER', 'always') == 'always'
        config.profiles_sample_rate = sample_rate(env, 'SENTRY_PROFILES_SAMPLE_RATE', 1.0)
      end

      def sample_rate(env, key, default)
        value = env[key]
        return default if value.nil? || value.to_s.strip.empty?

        Float(value)
      rescue ArgumentError, TypeError
        default
      end

      def always_sample
        lambda { |_context| true }
      end
    end
  end
end
