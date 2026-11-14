# frozen_string_literal: true

require_relative 'test_helper'
require 'sentry-ruby'
require 'better_together/sentry/configuration'
require 'better_together/sentry/reporter'

class BetterTogetherSentryReporterTest < Minitest::Test
  IN_MEMORY = lambda do |config|
    config.transport.transport_class = Sentry::DummyTransport
    config.background_worker_threads = 0
    config.sdk_logger = Logger.new(nil) if config.respond_to?(:sdk_logger=)
  end

  def reporter_for(platform)
    BetterTogether::Sentry::Reporter.new(platform_resolver: -> { platform }, client_config: IN_MEMORY)
  end

  def sent_events(reporter)
    reporter.instance_variable_get(:@hubs).values.flat_map { |hub| hub.current_client.transport.events }
  end

  def error
    raise 'boom'
  rescue StandardError => e
    e
  end

  CONTEXT = { request_id: 'r1', request_method: 'GET', path: '/people/1?token=secret', controller: 'people',
              action: 'show', user_id: 'u-42' }.freeze

  def platform(extra = {})
    FakePlatform.new({ 'sentry.dsn' => SentryFixtures::DSN_A }.merge(extra))
  end

  def test_platform_without_a_dsn_reports_nothing
    reporter = reporter_for(FakePlatform.new)

    assert_nil reporter.call(error, context: CONTEXT)
    assert_empty sent_events(reporter)
  end

  def test_essential_tier_sends_the_error_and_location_but_no_identity_or_query_string
    reporter = reporter_for(platform)
    reporter.call(error, context: CONTEXT)
    event = sent_events(reporter).first.to_h

    assert_equal 'GET', event[:extra][:request_method]
    assert_equal '/people/1', event[:extra][:path]
    refute event[:extra].key?(:user_id)
    assert_nil event[:user]&.fetch(:id, nil)
    refute_includes event.to_s, 'secret'
  end

  def test_user_id_needs_the_platform_flag_and_analytics_consent
    consent = { consent: { 'analytics' => true } }

    flagged = reporter_for(platform('sentry.identify_users' => true))
    flagged.call(error, context: CONTEXT.merge(consent))
    assert_equal 'u-42', sent_events(flagged).first.to_h[:user][:id]

    no_consent = reporter_for(platform('sentry.identify_users' => true))
    no_consent.call(error, context: CONTEXT)
    assert_nil sent_events(no_consent).first.to_h[:user]&.fetch(:id, nil)

    not_flagged = reporter_for(platform)
    not_flagged.call(error, context: CONTEXT.merge(consent))
    assert_nil sent_events(not_flagged).first.to_h[:user]&.fetch(:id, nil)
  end

  def test_email_and_ip_are_never_sent
    reporter = reporter_for(platform('sentry.identify_users' => true))
    reporter.call(error, context: CONTEXT.merge(consent: { analytics: true }, email: 'a@b.c', ip: '10.0.0.1'))
    event = sent_events(reporter).first.to_h
    text = event.slice(:extra, :user, :request, :tags, :contexts).to_s

    refute_includes text, 'a@b.c'
    refute_includes text, '10.0.0.1'
  end

  def test_two_platforms_use_separate_clients_and_dsns
    first = reporter_for(platform)
    first.call(error, context: CONTEXT)
    second = reporter_for(FakePlatform.new('sentry.dsn' => SentryFixtures::DSN_B))
    second.call(error, context: CONTEXT)

    hubs = [first, second].map { |r| r.instance_variable_get(:@hubs).values.first.current_client.configuration.dsn.to_s }
    assert_equal [SentryFixtures::DSN_A, SentryFixtures::DSN_B], hubs
  end
end
