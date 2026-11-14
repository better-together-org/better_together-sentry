# frozen_string_literal: true

# Platform stand-in answering integration_setting like CE's registry-backed method: the stored
# value, else the environment fallback for the host platform only. Two platforms with different
# settings are the core fixture for the per-platform tests.
class FakePlatform
  ENV_KEYS = { 'sentry.dsn' => 'SENTRY_DSN', 'sentry.client_key' => 'SENTRY_CLIENT_KEY',
               'sentry.environment' => 'SENTRY_ENVIRONMENT',
               'sentry.traces_sample_rate' => 'SENTRY_TRACES_SAMPLE_RATE' }.freeze

  def self.host(values = {}) = new(values).tap { |platform| platform.instance_variable_set(:@host, true) }

  def initialize(values = {})
    @values = values
    @host = false
  end

  def integration_setting(key)
    stored = @values[key]
    return stored unless stored.nil? || stored == ''
    return unless @host && ENV_KEYS.key?(key)

    ENV[ENV_KEYS.fetch(key)].to_s.empty? ? nil : ENV.fetch(ENV_KEYS.fetch(key))
  end
end

module SentryFixtures
  DSN_A = 'https://aaaa1111bbbb2222@o111.ingest.sentry.io/1'
  DSN_B = 'https://cccc3333dddd4444@o222.ingest.sentry.io/2'
  KEY_A = 'aaaa1111bbbb2222cccc3333dddd4444'
  KEY_B = '1111aaaa2222bbbb3333cccc4444dddd'
end
