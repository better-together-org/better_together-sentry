# frozen_string_literal: true

require_relative 'test_helper'
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

  def test_origins_for_a_platform_with_a_client_key_and_dsn
    platform = FakePlatform.new('sentry.dsn' => SentryFixtures::DSN_A, 'sentry.client_key' => SentryFixtures::KEY_A)
    origins = BetterTogether::Sentry::CspSources.origins_for(platform)

    assert_equal ['https://js-de.sentry-cdn.com'], origins[:script_src]
    assert_equal ['https://o111.ingest.sentry.io'], origins[:connect_src]
  end

  def test_origins_for_a_platform_without_a_client_key_are_empty
    platform = FakePlatform.new('sentry.dsn' => SentryFixtures::DSN_A)

    assert_equal({ script_src: [], connect_src: [] }, BetterTogether::Sentry::CspSources.origins_for(platform))
  end

  def test_replay_adds_the_integration_loader_origin
    platform = FakePlatform.new('sentry.dsn' => SentryFixtures::DSN_A, 'sentry.client_key' => SentryFixtures::KEY_A,
                                'sentry.replay_enabled' => true)

    assert_includes BetterTogether::Sentry::CspSources.origins_for(platform)[:script_src], 'https://browser.sentry-cdn.com'
  end
end
