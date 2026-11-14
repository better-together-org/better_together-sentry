# frozen_string_literal: true

module BetterTogether
  module Sentry
    # Per-platform Sentry settings, declared through CE's PlatformSettingsRegistry. The platform value
    # wins; the host-only environment fallback (SENTRY_*) is applied by CE's registry. Outside CE
    # (platform nil) the environment is read directly so the bootstrap keeps working.
    module Settings
      module_function

      # https://<public key>[:<legacy secret>]@<host>[/<path>]/<project id>
      DSN_FORMAT = %r{\Ahttps://[0-9a-f]{8,64}(?::[^@/\s]+)?@[A-Za-z0-9.-]+(?::\d+)?(?:/[A-Za-z0-9._~-]+)*/\d+\z}i
      CLIENT_KEY_FORMAT = /\A[0-9a-f]{16,64}\z/i
      ENVIRONMENT_FORMAT = /\A[A-Za-z0-9_.-]{1,64}\z/
      RATE_FORMAT = /\A(?:0(?:\.\d+)?|1(?:\.0+)?)\z/
      DEFAULT_TRACES_RATE = 0.05
      GROUP = 'Sentry error reporting'

      ENV_KEYS = {
        'dsn' => 'SENTRY_DSN', 'client_key' => 'SENTRY_CLIENT_KEY',
        'environment' => 'SENTRY_ENVIRONMENT', 'traces_sample_rate' => 'SENTRY_TRACES_SAMPLE_RATE'
      }.freeze

      # What a platform has configured, already validated. Invalid values read as unset.
      Resolved = Struct.new(:dsn, :client_key, :environment, :traces_sample_rate, :replay_enabled, :identify_users,
                            keyword_init: true) do
        def server? = !dsn.nil?
        def browser? = !client_key.nil?
        def configured? = server? || browser?
        # Session replay records what people see, so it is an analytics-tier feature.
        def replay? = browser? && replay_enabled == true
        # Attaching the signed-in person's id to server errors is analytics-tier too.
        def identify? = server? && identify_users == true

        # Never print the DSN key.
        def inspect = "#<Sentry settings dsn=#{Settings.mask(dsn)} browser=#{browser?} replay=#{replay?}>"
      end

      def resolve(platform, env: ENV)
        Resolved.new(
          dsn: valid(raw(platform, 'dsn', env), DSN_FORMAT),
          client_key: valid(raw(platform, 'client_key', env), CLIENT_KEY_FORMAT),
          environment: valid(raw(platform, 'environment', env), ENVIRONMENT_FORMAT),
          traces_sample_rate: traces_rate(raw(platform, 'traces_sample_rate', env)),
          replay_enabled: raw(platform, 'replay_enabled', env) == true,
          identify_users: raw(platform, 'identify_users', env) == true
        )
      end

      def raw(platform, field, env)
        if platform.respond_to?(:integration_setting)
          platform.integration_setting("sentry.#{field}")
        elsif platform.nil? && ENV_KEYS.key?(field)
          env.fetch(ENV_KEYS.fetch(field), nil)
        end
      end

      def valid(value, format)
        text = value.to_s.strip
        text if format.match?(text)
      end

      def traces_rate(value)
        text = value.to_s.strip
        RATE_FORMAT.match?(text) ? Float(text) : DEFAULT_TRACES_RATE
      end

      # "https://abcd...@host/1": enough to recognise a DSN in a log, not enough to use it.
      def mask(dsn)
        return '(none)' if dsn.nil?

        dsn.to_s.sub(%r{\A(https://[0-9a-f]{4})[^@]*@}i, '\1...@')
      end

      def register!
        return unless BetterTogether.respond_to?(:register_platform_setting)

        register_text_settings
        register_flag_settings
      end

      def register_text_settings
        {
          'dsn' => ['Server DSN', DSN_FORMAT, true, nil,
                    'https://<key>@<host>/<project>. Blank turns server error reporting off for this platform.'],
          'client_key' => ['Browser client key', CLIENT_KEY_FORMAT, false, nil,
                           'The key from the Sentry loader script URL. Blank turns browser error reporting off.'],
          'environment' => ['Environment', ENVIRONMENT_FORMAT, false, nil, 'For example production or staging.'],
          'traces_sample_rate' => ['Traces sample rate', RATE_FORMAT, false, DEFAULT_TRACES_RATE.to_s,
                                   'A number from 0 to 1 for server performance traces.']
        }.each do |field, (label, pattern, secret, default, hint)|
          BetterTogether.register_platform_setting(
            "sentry.#{field}", label:, hint:, pattern:, secret:, default:, group_label: GROUP,
                               env_fallback: ENV_KEYS.fetch(field)
          )
        end
      end

      def register_flag_settings
        {
          'replay_enabled' => ['Record session replays (needs analytics consent)',
                               'Replays are masked, load only after the visitor agrees to analytics, and stop when they withdraw.'],
          'identify_users' => ['Attach the signed-in person id to server errors (needs analytics consent)',
                               'Never sends email addresses or IP addresses.']
        }.each do |field, (label, hint)|
          BetterTogether.register_platform_setting("sentry.#{field}", type: :boolean, label:, hint:, default: false,
                                                                      group_label: GROUP)
        end
      end
    end
  end
end
