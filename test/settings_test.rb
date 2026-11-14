# frozen_string_literal: true

require_relative 'test_helper'
require 'better_together/sentry/settings'

class BetterTogetherSentrySettingsTest < Minitest::Test
  include EnvHelper

  Settings = BetterTogether::Sentry::Settings

  def test_two_platforms_resolve_their_own_values
    one = Settings.resolve(FakePlatform.new('sentry.dsn' => SentryFixtures::DSN_A, 'sentry.environment' => 'production'))
    two = Settings.resolve(FakePlatform.new('sentry.dsn' => SentryFixtures::DSN_B))

    assert_equal SentryFixtures::DSN_A, one.dsn
    assert_equal 'production', one.environment
    assert_equal SentryFixtures::DSN_B, two.dsn
    assert_nil two.environment
  end

  def test_invalid_values_read_as_unset
    resolved = Settings.resolve(FakePlatform.new('sentry.dsn' => 'http://insecure@x.io/1', 'sentry.client_key' => 'zz',
                                                 'sentry.environment' => 'a b', 'sentry.traces_sample_rate' => '7'))

    assert_nil resolved.dsn
    assert_nil resolved.client_key
    assert_nil resolved.environment
    refute resolved.configured?
    assert_in_delta 1.0, resolved.traces_sample_rate
  end

  def test_dsn_format
    good = ['https://abcdef0123456789@o1.ingest.sentry.io/12', 'https://abcdef0123456789@sentry.example.org:9000/p/3']
    bad = ['', 'https://nokey.example.org/1', 'ftp://abcdef0123456789@x.io/1', 'https://abcdef0123456789@x.io/abc']

    good.each { |dsn| assert_match Settings::DSN_FORMAT, dsn }
    bad.each { |dsn| refute_match Settings::DSN_FORMAT, dsn }
  end

  def test_traces_sample_rate_is_a_number_between_zero_and_one
    assert_in_delta 0.25, Settings.resolve(FakePlatform.new('sentry.traces_sample_rate' => '0.25')).traces_sample_rate
    assert_in_delta 0.0, Settings.resolve(FakePlatform.new('sentry.traces_sample_rate' => '0')).traces_sample_rate
    assert_in_delta 1.0, Settings.resolve(FakePlatform.new('sentry.traces_sample_rate' => '1.5')).traces_sample_rate
  end

  def test_environment_fallback_is_for_the_host_platform_only
    with_env('SENTRY_DSN' => SentryFixtures::DSN_A) do
      assert_equal SentryFixtures::DSN_A, Settings.resolve(FakePlatform.host).dsn
      assert_nil Settings.resolve(FakePlatform.new).dsn
      assert_equal SentryFixtures::DSN_B,
                   Settings.resolve(FakePlatform.host('sentry.dsn' => SentryFixtures::DSN_B)).dsn
    end
  end

  def test_without_ce_the_environment_is_read_directly
    assert_equal SentryFixtures::DSN_A, Settings.resolve(nil, env: { 'SENTRY_DSN' => SentryFixtures::DSN_A }).dsn
  end

  def test_replay_and_identity_need_their_basics
    flags = { 'sentry.replay_enabled' => true, 'sentry.identify_users' => true }

    refute Settings.resolve(FakePlatform.new(flags)).replay?
    refute Settings.resolve(FakePlatform.new(flags)).identify?
    assert Settings.resolve(FakePlatform.new(flags.merge('sentry.client_key' => SentryFixtures::KEY_A))).replay?
    assert Settings.resolve(FakePlatform.new(flags.merge('sentry.dsn' => SentryFixtures::DSN_A))).identify?
  end

  def test_secrets_are_masked
    assert_equal 'https://aaaa...@o111.ingest.sentry.io/1', Settings.mask(SentryFixtures::DSN_A)
    assert_equal '(none)', Settings.mask(nil)
    refute_includes Settings.resolve(FakePlatform.new('sentry.dsn' => SentryFixtures::DSN_A)).inspect, 'bbbb2222'
  end

  def test_register_declares_the_dsn_as_secret_and_env_backed
    registered = {}
    BetterTogether.singleton_class.send(:define_method, :register_platform_setting) { |key, **opts| registered[key] = opts }
    Settings.register!

    assert registered['sentry.dsn'][:secret]
    assert_equal 'SENTRY_DSN', registered['sentry.dsn'][:env_fallback]
    assert_equal false, registered['sentry.replay_enabled'][:default]
    assert_equal :boolean, registered['sentry.identify_users'][:type]
    refute registered.key?('sentry.send_default_pii')
  ensure
    BetterTogether.singleton_class.send(:remove_method, :register_platform_setting)
  end
end
