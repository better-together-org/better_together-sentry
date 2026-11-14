# frozen_string_literal: true

require 'erb'
require 'json'
require 'better_together/sentry/settings'

module BetterTogether
  module Sentry
    # Browser Sentry. The basic error script (no replay, no identity, no cookies) is the essential tier
    # and loads for every visitor of a platform that has a client key. Session replay is added in the
    # browser only after the visitor agrees to the analytics category, and removed again on withdrawal.
    module HeadTags
      module_function

      def render(view_context)
        platform = view_context.host_platform if view_context.respond_to?(:host_platform)
        settings = Settings.resolve(platform)
        return unless settings.browser?

        nonce = view_context.content_security_policy_nonce
        pieces = [
          view_context.javascript_tag(bootstrap_js(settings, policy_version(view_context, platform)), nonce:),
          view_context.javascript_include_tag(
            "https://js-de.sentry-cdn.com/#{ERB::Util.url_encode(settings.client_key)}.min.js",
            crossorigin: 'anonymous', nonce:
          )
        ]
        view_context.safe_join(pieces, "\n")
      end

      def policy_version(view_context, platform)
        if view_context.respond_to?(:consent_policy_version)
          view_context.consent_policy_version(platform)
        elsif defined?(BetterTogether::Consent)
          BetterTogether::Consent.policy_version(platform)
        end
      end

      # Runs before the loader script. Replay sample rates stay 0 unless the visitor agreed; the
      # beforeSend hook drops identity fields so nothing personal leaves in the essential tier.
      def bootstrap_js(settings, policy_version = nil)
        options = { sendDefaultPii: false, replaysSessionSampleRate: 0, replaysOnErrorSampleRate: 0,
                    tracesSampleRate: 0 }
        options[:environment] = settings.environment if settings.environment
        <<~JS.strip
          window.sentryOnLoad = function() {
            var options = #{json(options)};
            options.beforeSend = function(event) { delete event.user; if (event.request) { delete event.request.cookies; } return event; };
            Sentry.init(options);
            #{replay_js(policy_version) if settings.replay?}
          };
        JS
      end

      # Replay is consent gated twice: it starts only from a granted analytics decision (the bt_consent
      # cookie at load, or the better_together:consent event) and stops when that is withdrawn.
      def replay_js(policy_version)
        <<~JS.strip
          var replay = null;
          var policyVersion = #{json(policy_version)};
          function setReplay(c) {
            var granted = !!(c && c.analytics);
            if (granted && !replay && Sentry.lazyLoadIntegration) {
              replay = 'loading';
              Sentry.lazyLoadIntegration('replayIntegration').then(function(factory) {
                var client = Sentry.getClient();
                if (client) { client.getOptions().replaysSessionSampleRate = 0.1; client.getOptions().replaysOnErrorSampleRate = 1.0; }
                replay = factory({ maskAllText: true, maskAllInputs: true, blockAllMedia: true });
                Sentry.addIntegration(replay);
              }).catch(function() { replay = null; });
            } else if (!granted && replay && replay !== 'loading') {
              replay.stop();
              replay = null;
            }
          }
          try {
            var match = document.cookie.match(/(?:^|; )bt_consent=([^;]*)/);
            var saved = match ? JSON.parse(decodeURIComponent(match[1])) : null;
            if (saved && saved.v === 1 && (!policyVersion || saved.pv === policyVersion)) setReplay(saved);
          } catch (e) {}
          window.addEventListener('better_together:consent', function(event) { setReplay(event && event.detail); });
        JS
      end

      JSON_ESCAPES = { '<' => '\\u003c', '>' => '\\u003e', '&' => '\\u0026', "\u2028" => '\\u2028', "\u2029" => '\\u2029' }.freeze

      # JSON that is safe inside an inline script (no </script> breakout).
      def json(value)
        value.to_json.gsub(/[<>&\u2028\u2029]/, JSON_ESCAPES)
      end
    end
  end
end
