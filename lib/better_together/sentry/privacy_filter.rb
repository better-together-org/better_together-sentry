# frozen_string_literal: true

module BetterTogether
  module Sentry
    # Keeps personal data out of events. Email addresses, usernames and IP addresses are never sent;
    # a person id appears only when the Reporter set it after analytics consent.
    module PrivacyFilter
      module_function

      REQUEST_KEYS = %i[request_id request_method controller action path job_class job_id queue_name].freeze

      def scrub(event)
        user = event.respond_to?(:user) ? event.user : nil
        if user.respond_to?(:delete)
          %i[email username ip_address].each { |key| user.delete(key) }
          %w[email username ip_address].each { |key| user.delete(key) }
        end
        event.request.cookies = nil if event.respond_to?(:request) && event.request.respond_to?(:cookies=)
        event
      end

      # The essential-tier context: what is needed to find the failing code, never who was using it.
      def essential_context(context)
        kept = context.to_h.transform_keys(&:to_sym).slice(*REQUEST_KEYS)
        kept[:path] = kept[:path].to_s.split('?', 2).first if kept.key?(:path)
        kept
      end
    end
  end
end
