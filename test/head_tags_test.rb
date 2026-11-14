# frozen_string_literal: true

require_relative 'test_helper'
require 'better_together/sentry/head_tags'

class BetterTogetherSentryHeadTagsTest < Minitest::Test
  include EnvHelper

  # View double exposing the helpers HeadTags uses on a CE request.
  class View
    attr_reader :host_platform

    def initialize(platform = nil, nonce: 'nonce-123')
      @host_platform = platform
      @nonce = nonce
    end

    def content_security_policy_nonce = @nonce

    def javascript_include_tag(src, crossorigin:, nonce:)
      %(<script crossorigin="#{crossorigin}" nonce="#{nonce}" src="#{src}"></script>)
    end

    def javascript_tag(content, nonce:)
      %(<script nonce="#{nonce}">#{content}</script>)
    end

    def safe_join(parts, separator) = parts.join(separator)
  end

  def render(platform)
    BetterTogether::Sentry::HeadTags.render(View.new(platform))
  end

  def test_nothing_without_a_client_key
    assert_nil render(FakePlatform.new('sentry.dsn' => SentryFixtures::DSN_A))
  end

  def test_nonce_safe_markup_for_a_platform_with_a_client_key
    out = render(FakePlatform.new('sentry.client_key' => SentryFixtures::KEY_A))

    assert_includes out, "https://js-de.sentry-cdn.com/#{SentryFixtures::KEY_A}.min.js"
    assert_includes out, 'crossorigin="anonymous"'
    assert_includes out, 'nonce="nonce-123"'
  end

  def test_two_platforms_get_their_own_keys
    first = render(FakePlatform.new('sentry.client_key' => SentryFixtures::KEY_A))
    second = render(FakePlatform.new('sentry.client_key' => SentryFixtures::KEY_B))

    assert_includes first, SentryFixtures::KEY_A
    refute_includes first, SentryFixtures::KEY_B
    assert_includes second, SentryFixtures::KEY_B
  end

  def test_invalid_client_key_renders_nothing
    assert_nil render(FakePlatform.new('sentry.client_key' => 'not a key!'))
  end

  def test_env_fallback_applies_to_the_host_platform_only
    with_env('SENTRY_CLIENT_KEY' => SentryFixtures::KEY_A) do
      assert_includes render(FakePlatform.host), SentryFixtures::KEY_A
      assert_nil render(FakePlatform.new)
    end
  end

  def test_basic_script_is_essential_tier_no_replay_no_identity
    out = render(FakePlatform.new('sentry.client_key' => SentryFixtures::KEY_A))

    assert_includes out, '"sendDefaultPii":false'
    assert_includes out, '"replaysSessionSampleRate":0'
    assert_includes out, 'delete event.user'
    refute_includes out, 'replayIntegration'
    refute_includes out, 'bt_consent'
  end

  def test_replay_code_is_present_only_when_enabled_and_waits_for_consent
    out = render(FakePlatform.new('sentry.client_key' => SentryFixtures::KEY_A, 'sentry.replay_enabled' => true))

    assert_includes out, "lazyLoadIntegration('replayIntegration')"
    assert_includes out, 'better_together:consent'
    assert_includes out, 'bt_consent='
    assert_includes out, 'maskAllText: true'
    assert_includes out, 'replay.stop()'
    assert_operator out.index('window.sentryOnLoad'), :<, out.index('function setReplay')
  end

  def test_environment_is_embedded_only_when_valid
    ok = render(FakePlatform.new('sentry.client_key' => SentryFixtures::KEY_A, 'sentry.environment' => 'staging'))
    bad = render(FakePlatform.new('sentry.client_key' => SentryFixtures::KEY_A, 'sentry.environment' => '</script>'))

    assert_includes ok, '"environment":"staging"'
    refute_includes bad, 'environment'
    refute_includes bad, '</script>x'
  end

  def test_the_init_script_precedes_the_loader
    out = render(FakePlatform.new('sentry.client_key' => SentryFixtures::KEY_A))

    assert_operator out.index('window.sentryOnLoad'), :<, out.index('.min.js')
  end
end
