# frozen_string_literal: true

require 'minitest/autorun'
require 'better_together/sentry/head_tags'

class BetterTogetherSentryHeadTagsTest < Minitest::Test
  FakeViewContext = Struct.new(:nonce) do
    def content_security_policy_nonce
      nonce
    end

    def javascript_include_tag(src, crossorigin:, nonce:)
      %(<script crossorigin="#{crossorigin}" nonce="#{nonce}" src="#{src}"></script>)
    end
  end

  def with_sentry_client_key(value)
    original = ENV.fetch('SENTRY_CLIENT_KEY', nil)
    value.nil? ? ENV.delete('SENTRY_CLIENT_KEY') : ENV['SENTRY_CLIENT_KEY'] = value
    yield
  ensure
    original.nil? ? ENV.delete('SENTRY_CLIENT_KEY') : ENV['SENTRY_CLIENT_KEY'] = original
  end

  def test_render_returns_nil_when_sentry_client_key_is_blank
    with_sentry_client_key(nil) do
      assert_nil BetterTogether::Sentry::HeadTags.render(FakeViewContext.new('nonce-123'))
    end
  end

  def test_render_builds_nonce_safe_sentry_markup
    rendered = with_sentry_client_key('abc123') do
      BetterTogether::Sentry::HeadTags.render(FakeViewContext.new('nonce-123'))
    end

    assert_includes rendered, 'https://js-de.sentry-cdn.com/abc123.min.js'
    assert_includes rendered, 'crossorigin="anonymous"'
    assert_includes rendered, 'nonce="nonce-123"'
  end
end
