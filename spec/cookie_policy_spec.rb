# frozen_string_literal: true

require_relative 'spec_helper'
require_relative '../test/support/fake_platform'

RSpec.describe 'Sentry cookie policy and consent registration' do
  include_context 'with an isolated cookie policy registry' if CE_CONSENT_API

  let(:dsn) { SentryFixtures::DSN_A }
  let(:key) { SentryFixtures::KEY_A }
  let(:basic) { FakePlatform.new('sentry.dsn' => dsn, 'sentry.client_key' => key) }
  let(:replay) { FakePlatform.new('sentry.dsn' => dsn, 'sentry.client_key' => key, 'sentry.replay_enabled' => true) }
  let(:unconfigured) { FakePlatform.new }

  before do
    next unless CE_CONSENT_API

    BetterTogether::Sentry::Policy.register!
  end

  describe 'replay segment on a platform that opted in' do
    let(:platform) { replay }

    it_behaves_like 'a cookie policy segment', :sentry_replay, category: :analytics if CE_CONSENT_API
  end

  describe 'essential error reporting segment' do
    it 'is disclosed on configured platforms without a banner', :aggregate_failures do
      segment = BetterTogether::CookiePolicy.resolved_segments(basic).find { |s| s.key == :sentry }

      expect(segment.category).to eq('essential')
      expect(segment.cookies).to be_empty
      expect(segment.description).to include('No cookies')
      expect(BetterTogether::Consent.provider_categories(basic)).to be_empty
      expect(BetterTogether::Consent.categories_in_use(basic)).to be_empty
    end

    it 'is hidden on a platform with nothing configured' do
      keys = BetterTogether::CookiePolicy.resolved_segments(unconfigured).map(&:key)

      expect(keys).not_to include(:sentry, :sentry_replay)
    end
  end

  describe 'two platforms' do
    it 'asks for analytics only where replay is enabled', :aggregate_failures do
      expect(BetterTogether::Consent.provider_categories(replay)).to eq(%w[analytics])
      expect(BetterTogether::Consent.provider_categories(basic)).to eq([])
      expect(BetterTogether::Consent.policy_version(replay)).not_to eq(BetterTogether::Consent.policy_version(basic))
    end

    it 'does not show the replay segment on the basic platform' do
      expect(BetterTogether::CookiePolicy.resolved_segments(basic).map(&:key)).not_to include(:sentry_replay)
    end
  end

  describe 'environment fallback' do
    around do |example|
      saved = ENV.values_at('SENTRY_DSN', 'SENTRY_CLIENT_KEY')
      ENV['SENTRY_DSN'] = dsn
      ENV['SENTRY_CLIENT_KEY'] = key
      example.run
    ensure
      ENV['SENTRY_DSN'], ENV['SENTRY_CLIENT_KEY'] = saved
    end

    it 'configures the host platform only', :aggregate_failures do
      host = FakePlatform.host
      keys = ->(platform) { BetterTogether::CookiePolicy.resolved_segments(platform).map(&:key) }

      expect(keys.call(host)).to include(:sentry)
      expect(keys.call(FakePlatform.new)).not_to include(:sentry)
    end
  end
end
