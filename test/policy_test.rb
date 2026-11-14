# frozen_string_literal: true

require_relative 'test_helper'
require 'better_together/sentry/policy'
require 'better_together/sentry/consent_gate'

class BetterTogetherSentryPolicyTest < Minitest::Test
  Policy = BetterTogether::Sentry::Policy

  def platform(values = {})
    FakePlatform.new({ 'sentry.dsn' => SentryFixtures::DSN_A, 'sentry.client_key' => SentryFixtures::KEY_A }.merge(values))
  end

  def test_no_consent_category_for_the_essential_tier
    assert_equal false, Policy.consent_categories(platform)
    assert_equal false, Policy.consent_categories(FakePlatform.new)
  end

  def test_replay_or_identity_needs_analytics
    assert_equal :analytics, Policy.consent_categories(platform('sentry.replay_enabled' => true))
    assert_equal :analytics, Policy.consent_categories(platform('sentry.identify_users' => true))
  end

  def test_replay_without_a_client_key_needs_nothing
    only_dsn = FakePlatform.new('sentry.dsn' => SentryFixtures::DSN_A, 'sentry.replay_enabled' => true)

    assert_equal false, Policy.consent_categories(only_dsn)
  end

  def test_registers_an_essential_and_an_analytics_segment_with_conditions
    segments = {}
    BetterTogether.singleton_class.send(:define_method, :register_cookie_policy_segment) { |key, **opts| segments[key] = opts }
    Policy.register_segments!

    assert_equal :essential, segments[:sentry][:category]
    assert_empty segments[:sentry][:cookies]
    assert_equal :analytics, segments[:sentry_replay][:category]
    assert segments[:sentry][:if].call(platform)
    refute segments[:sentry][:if].call(FakePlatform.new)
    refute segments[:sentry_replay][:if].call(platform)
    assert segments[:sentry_replay][:if].call(platform('sentry.replay_enabled' => true))
  ensure
    BetterTogether.singleton_class.send(:remove_method, :register_cookie_policy_segment)
  end

  def test_consent_gate_reads_context_and_defaults_to_no
    gate = BetterTogether::Sentry::ConsentGate

    assert gate.analytics?(consent: { 'analytics' => true })
    assert gate.analytics?(consent: { analytics: true })
    assert gate.analytics?(consent: %i[analytics])
    refute gate.analytics?(consent: { analytics: false })
    refute gate.analytics?({})
  end
end
