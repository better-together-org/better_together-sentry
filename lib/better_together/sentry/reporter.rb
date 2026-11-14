# frozen_string_literal: true

require 'better_together/sentry/settings'
require 'better_together/sentry/consent_gate'
require 'better_together/sentry/privacy_filter'

module BetterTogether
  module Sentry
    # Sends exceptions to the Sentry project of the platform the failure happened on.
    #
    # Essential tier (no banner, disclosed in the cookie policy): the error, its backtrace and where it
    # happened (request id, controller, action, path without query string). Beyond that tier, the
    # signed-in person's id is attached only when the platform enabled it AND the person agreed to
    # analytics. Email addresses and IP addresses are never attached.
    class Reporter
      # client_config: optional block to adjust each per-platform client's configuration (tests use it
      # to install an in-memory transport).
      def initialize(platform_resolver: nil, client_config: nil)
        @client_config = client_config
        @platform_resolver = platform_resolver || method(:current_platform)
        @hubs = {}
        @lock = Mutex.new
      end

      def call(exception, context: {})
        settings = Settings.resolve(@platform_resolver.call)
        return unless settings.server?

        hub = hub_for(settings)
        hub.capture_exception(exception) { |scope| decorate(scope, settings, context.to_h) }
      end

      private

      def decorate(scope, settings, context)
        scope.set_extras(PrivacyFilter.essential_context(context))
        scope.set_user(id: context[:user_id].to_s) if identify?(settings, context)
      end

      def identify?(settings, context)
        settings.identify? && !context[:user_id].to_s.empty? && context[:user_id].to_s != 'anonymous' &&
          !context[:private_page] && ConsentGate.analytics?(context)
      end

      # The process-wide Sentry (initialised from SENTRY_DSN) serves the platform whose DSN it is;
      # any other DSN gets its own client so platforms never report into each other's projects.
      def hub_for(settings)
        return ::Sentry.get_current_hub if ::Sentry.initialized? && ::Sentry.configuration.dsn&.to_s == settings.dsn

        key = [settings.dsn, settings.environment, settings.traces_sample_rate]
        @lock.synchronize { @hubs[key] ||= build_hub(settings) }
      end

      def build_hub(settings)
        config = ::Sentry::Configuration.new
        Configuration.apply_platform(config, settings)
        @client_config&.call(config)
        ::Sentry::Hub.new(::Sentry::Client.new(config), ::Sentry::Scope.new)
      end

      def current_platform
        return unless defined?(::Current)

        ::Current.platform || ::Current.host_platform
      end
    end
  end
end
