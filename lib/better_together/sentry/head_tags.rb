# frozen_string_literal: true

require 'erb'

module BetterTogether
  module Sentry
    module HeadTags
      module_function

      def render(view_context)
        client_key = ENV.fetch('SENTRY_CLIENT_KEY', '').to_s.strip
        return if client_key.empty?

        nonce = view_context.content_security_policy_nonce
        view_context.javascript_include_tag(
          "https://js-de.sentry-cdn.com/#{ERB::Util.url_encode(client_key)}.min.js",
          crossorigin: 'anonymous',
          nonce:
        )
      end
    end
  end
end
