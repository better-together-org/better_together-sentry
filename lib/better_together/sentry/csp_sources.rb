# frozen_string_literal: true

require 'uri'
require 'better_together/sentry/settings'

module BetterTogether
  module Sentry
    module CspSources
      module_function

      SCRIPT_ORIGIN = 'https://js-de.sentry-cdn.com'
      REPLAY_SCRIPT_ORIGIN = 'https://browser.sentry-cdn.com'

      # Origins one platform needs: its ingest host for server-independent browser reporting only when
      # it has a client key, and the CDN script origin likewise. Nothing for a platform without them.
      def origins_for(platform, env: ENV)
        settings = Settings.resolve(platform, env:)
        {
          script_src: script_origins(settings),
          connect_src: settings.browser? ? [origin_for_url(settings.dsn), origin_for_url(env.fetch('SENTRY_TUNNEL', nil))].compact.uniq : []
        }
      end

      def script_origins(settings)
        return [] unless settings.browser?

        settings.replay? ? [SCRIPT_ORIGIN, REPLAY_SCRIPT_ORIGIN] : [SCRIPT_ORIGIN]
      end

      def connect_sources(env = ENV)
        [
          origin_for_url(env.fetch('SENTRY_DSN', nil)),
          origin_for_url(env.fetch('SENTRY_TUNNEL', nil))
        ].compact.uniq
      end

      def origin_for_url(value)
        url = value.to_s.strip
        return if url.empty?

        uri = URI.parse(url)
        return unless uri.is_a?(URI::HTTP) && uri.host
        return unless uri.scheme == 'https'

        "#{uri.scheme}://#{uri.host}#{normalized_port(uri)}"
      rescue URI::InvalidURIError
        nil
      end

      def normalized_port(uri)
        return '' if uri.port.nil? || [80, 443].include?(uri.port)

        ":#{uri.port}"
      end
    end
  end
end
