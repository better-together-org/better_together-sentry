# frozen_string_literal: true

require_relative 'test_helper'
require 'better_together/sentry/configuration'

class BetterTogetherSentryConfigurationTest < Minitest::Test
  FakeConfig = Struct.new(
    :dsn,
    :release,
    :breadcrumbs_logger,
    :traces_sample_rate,
    :traces_sampler,
    :profiles_sample_rate,
    :environment,
    :send_default_pii,
    :before_send,
    keyword_init: true
  )

  def with_fake_sentry(initialized: false)
    original_sentry = Object.send(:remove_const, :Sentry) if Object.const_defined?(:Sentry)

    fake_sentry = Module.new do
      @initialized = initialized
      @config = nil

      class << self
        attr_reader :config

        def initialized?
          @initialized
        end

        def init
          @config = BetterTogetherSentryConfigurationTest::FakeConfig.new
          yield @config
          @initialized = true
        end
      end
    end

    Object.const_set(:Sentry, fake_sentry)
    yield fake_sentry
  ensure
    Object.send(:remove_const, :Sentry) if Object.const_defined?(:Sentry)
    Object.const_set(:Sentry, original_sentry) if original_sentry
  end

  def test_bootstrap_is_noop_without_dsn
    with_fake_sentry do |fake_sentry|
      BetterTogether::Sentry::Configuration.bootstrap!({})

      assert_nil fake_sentry.config
      refute fake_sentry.initialized?
    end
  end

  def test_bootstrap_initializes_sentry_with_default_settings
    env = { 'SENTRY_DSN' => SentryFixtures::DSN_A, 'GIT_REV' => 'abc123' }

    with_fake_sentry do |fake_sentry|
      BetterTogether::Sentry::Configuration.bootstrap!(env)

      assert fake_sentry.initialized?
      assert_equal env['SENTRY_DSN'], fake_sentry.config.dsn
      assert_equal 'abc123', fake_sentry.config.release
      assert_equal %i[active_support_logger http_logger], fake_sentry.config.breadcrumbs_logger
      assert_equal 1.0, fake_sentry.config.traces_sample_rate
      assert_equal 1.0, fake_sentry.config.profiles_sample_rate
      assert fake_sentry.config.traces_sampler.call(Object.new)
      assert_equal false, fake_sentry.config.send_default_pii
      assert_respond_to fake_sentry.config.before_send, :call
    end
  end

  def test_bootstrap_respects_existing_sentry_initialization
    env = { 'SENTRY_DSN' => SentryFixtures::DSN_A }

    with_fake_sentry(initialized: true) do |fake_sentry|
      BetterTogether::Sentry::Configuration.bootstrap!(env)

      assert_nil fake_sentry.config
    end
  end

  def test_apply_defaults_uses_env_overrides
    config = FakeConfig.new
    env = {
      'SENTRY_DSN' => SentryFixtures::DSN_A,
      'GIT_REV' => 'rev-1',
      'SENTRY_TRACES_SAMPLE_RATE' => '0.25',
      'SENTRY_PROFILES_SAMPLE_RATE' => '0.5',
      'SENTRY_TRACES_SAMPLER' => 'disabled'
    }

    BetterTogether::Sentry::Configuration.apply_defaults(config, env)

    assert_equal env['SENTRY_DSN'], config.dsn
    assert_equal 'rev-1', config.release
    assert_equal 0.25, config.traces_sample_rate
    assert_equal 0.5, config.profiles_sample_rate
    assert_nil config.traces_sampler
  end

  def test_bootstrap_ignores_a_malformed_dsn
    with_fake_sentry do |fake_sentry|
      BetterTogether::Sentry::Configuration.bootstrap!({ 'SENTRY_DSN' => 'not-a-dsn' })

      assert_nil fake_sentry.config
    end
  end

  def test_apply_defaults_takes_the_environment_name
    config = FakeConfig.new

    BetterTogether::Sentry::Configuration.apply_defaults(
      config, { 'SENTRY_DSN' => SentryFixtures::DSN_A, 'SENTRY_ENVIRONMENT' => 'staging' }
    )

    assert_equal 'staging', config.environment
  end
end
