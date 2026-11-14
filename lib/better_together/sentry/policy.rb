# frozen_string_literal: true

require 'date'
require 'better_together/sentry/settings'

module BetterTogether
  module Sentry
    # What Sentry stores and which consent it needs, registered into CE's cookie policy and consent
    # registries. Decision (recorded in the README, the owner may overturn it): server error reporting
    # and the basic browser error script, with no replay and no personal data, are essential and are
    # only disclosed. Session replay and identifying people need the analytics category.
    module Policy
      module_function

      UPDATED_ON = Date.new(2026, 11, 14)
      PRIVACY_URL = 'https://sentry.io/privacy/'

      def settings_for(platform)
        Settings.resolve(platform)
      end

      # Analytics only when replay or person identification is switched on for the platform.
      def consent_categories(platform)
        settings = settings_for(platform)
        settings.replay? || settings.identify? ? :analytics : false
      end

      def register!
        register_consent!
        register_segments!
      end

      def register_consent!
        return unless BetterTogether.respond_to?(:register_consent_provider)

        BetterTogether.register_consent_provider(:sentry) { |platform| consent_categories(platform) }
      end

      def register_segments!
        return unless BetterTogether.respond_to?(:register_cookie_policy_segment)

        register_error_reporting_segment
        register_replay_segment
      end

      def register_error_reporting_segment
        BetterTogether.register_cookie_policy_segment(
          :sentry, category: :essential, title: 'Error reporting',
                   description: 'When something breaks, the platform sends the error and where it happened ' \
                                '(page, action, time) to Sentry so it can be fixed. No cookies are set, nothing ' \
                                'identifies you, and no email address or IP address is sent.',
                   cookies: [], privacy_url: PRIVACY_URL, updated_on: UPDATED_ON,
                   if: ->(platform) { settings_for(platform).configured? }
        )
      end

      def register_replay_segment
        BetterTogether.register_cookie_policy_segment(
          :sentry_replay, category: :analytics, title: 'Session replay and error reports with your account',
                          description: 'With your agreement, Sentry records a masked replay of what happened before ' \
                                       'an error, and error reports can carry your account number so we can follow ' \
                                       'up. Text and media are masked. Withdraw at any time in your cookie settings.',
                          cookies: [
                            { name: 'sentryReplaySession', purpose: 'Keeps one replay together while the tab is open ' \
                                                                    '(browser session storage, not a cookie).',
                              duration: 'Until the tab is closed', provider: 'Sentry', party: :third }
                          ],
                          privacy_url: PRIVACY_URL, updated_on: UPDATED_ON,
                          if: ->(platform) { consent_categories(platform) == :analytics }
        )
      end
    end
  end
end
