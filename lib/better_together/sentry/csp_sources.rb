# frozen_string_literal: true

require 'uri'

module BetterTogether
  module Sentry
    module CspSources
      module_function

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
