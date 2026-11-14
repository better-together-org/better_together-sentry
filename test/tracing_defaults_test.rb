# frozen_string_literal: true

require_relative 'test_helper'
require 'better_together/sentry/configuration'

class BetterTogetherSentryTracingDefaultsTest < Minitest::Test
  FakeConfig = Struct.new(
    :dsn, :release, :breadcrumbs_logger, :traces_sample_rate, :traces_sampler,
    :profiles_sample_rate, :environment, :send_default_pii, :before_send, :excluded_exceptions,
    keyword_init: true
  )

  DSN = 'https://0123456789abcdef0123@o1.ingest.sentry.io/1'

  def apply(env)
    config = FakeConfig.new(excluded_exceptions: [])
    BetterTogether::Sentry::Configuration.apply_defaults(config, { 'SENTRY_DSN' => DSN }.merge(env))
    config
  end

  def test_blank_git_rev_leaves_release_unset
    assert_nil apply('GIT_REV' => '  ').release
  end

  def test_out_of_range_or_invalid_rates_fall_back_to_defaults
    assert_equal 0.05, apply('SENTRY_TRACES_SAMPLE_RATE' => '5').traces_sample_rate
    assert_equal 0.05, apply('SENTRY_TRACES_SAMPLE_RATE' => '-1').traces_sample_rate
    assert_equal 0.0, apply('SENTRY_PROFILES_SAMPLE_RATE' => 'abc').profiles_sample_rate
  end

  def test_default_sampler_skips_noisy_paths_and_uses_rate
    sampler = apply('SENTRY_TRACES_SAMPLE_RATE' => '0.2').traces_sampler

    assert_in_delta 0.2, sampler.call(rack_env: { 'PATH_INFO' => '/en/events' }), 0.0001
    assert_equal 0.0, sampler.call(rack_env: { 'PATH_INFO' => '/healthcheck' })
    assert_equal 0.0, sampler.call(rack_env: { 'PATH_INFO' => '/assets/app.js' })
    assert_equal 0.0, sampler.call(rack_env: { 'PATH_INFO' => '/rails/active_storage/blobs/x' })
    assert_in_delta 0.2, sampler.call(rack_env: { 'PATH_INFO' => '/upload' }), 0.0001
    assert_in_delta 0.2, sampler.call({}), 0.0001
  end

  def test_default_sampler_honours_parent_decision
    sampler = apply({}).traces_sampler

    assert_equal true, sampler.call(parent_sampled: true, rack_env: { 'PATH_INFO' => '/healthcheck' })
    assert_equal false, sampler.call(parent_sampled: false, rack_env: { 'PATH_INFO' => '/en' })
  end

  def test_sampler_modes
    assert_equal true, apply('SENTRY_TRACES_SAMPLER' => 'always').traces_sampler.call({})
    assert_nil apply('SENTRY_TRACES_SAMPLER' => 'disabled').traces_sampler
  end
end
