# frozen_string_literal: true

require 'minitest/autorun'
require 'better_together/sentry/csp_sources'

class BetterTogetherSentryCspSourcesTest < Minitest::Test
  def test_connect_sources_uses_configured_https_origins
    env = {
      'SENTRY_DSN' => 'https://public@example.ingest.sentry.io/123',
      'SENTRY_TUNNEL' => 'https://errors.example.com/sentry-tunnel'
    }

    assert_equal(
      ['https://example.ingest.sentry.io', 'https://errors.example.com'],
      BetterTogether::Sentry::CspSources.connect_sources(env)
    )
  end

  def test_connect_sources_ignores_blank_and_invalid_values
    env = {
      'SENTRY_DSN' => '',
      'SENTRY_TUNNEL' => 'http://insecure.example.com/path'
    }

    assert_equal [], BetterTogether::Sentry::CspSources.connect_sources(env)
  end
end
