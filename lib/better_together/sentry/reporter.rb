# frozen_string_literal: true

module BetterTogether
  module Sentry
    class Reporter
      def call(exception, context: {})
        ::Sentry.capture_exception(exception, extra: context)
      end
    end
  end
end
