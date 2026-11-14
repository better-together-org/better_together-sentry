# Better Together Sentry

Thin provider gem that registers Sentry adapters into the Better Together adapter registry.

## Purpose

This gem keeps Sentry out of the Community Engine gem while allowing host apps to opt in to:

- error reporting
- browser Sentry head tags
- Sentry runtime bootstrap for apps that provide `SENTRY_DSN`
- future metrics/observability fan-out

## Usage

Add the gem to a CE host app and require it during boot.

```ruby
gem 'better_together-sentry', path: '../better_together-sentry'
```

The gem registers:

- a default `Sentry.init` bootstrap when `SENTRY_DSN` is present and Sentry has not already been initialized
- an `:error_reporting` adapter named `:sentry` when `Sentry` is loaded
- a head-tag provider for the browser Sentry CDN script when the platform has a client key
- the related CSP origins for the host platform
- platform settings, a consent provider and cookie policy segments (below)

## Per-platform settings

Requires a Community Engine with `BetterTogether.register_platform_setting` (the platform Integrations tab). Each platform sets its own values:

| Setting | Meaning |
|---------|---------|
| Server DSN | `https://<key>@<host>/<project>`. Blank turns server error reporting off for the platform. Masked in the form and never logged in full. |
| Browser client key | The key in the Sentry loader script URL. Blank turns the browser script off. |
| Environment | For example `production` or `staging`. |
| Traces sample rate | 0 to 1, server traces (default 1.0, as before). |
| Record session replays | Opt-in, needs analytics consent. |
| Attach person id to server errors | Opt-in, needs analytics consent. |

`SENTRY_DSN`, `SENTRY_CLIENT_KEY`, `SENTRY_ENVIRONMENT` and `SENTRY_TRACES_SAMPLE_RATE` still work, as a fallback for the host platform only (other platforms never inherit them). `GIT_REV` sets the release. `send_default_pii` is always false.

A platform without a DSN reports nothing: it never sends its errors into the host platform's project. The process-wide `Sentry.init` is made from the environment (host platform); any other DSN gets its own client.

## Consent decision (an assumption the owner can overturn)

- Essential, no banner, disclosed on the cookie policy page: server error reporting, and the basic browser error script with no replay, no cookies, no identity. Server events carry the error and where it happened (request id, method, controller, action, path without query string). Email addresses, usernames and IP addresses are never sent.
- Analytics category, loaded only after consent: session replay (masked text, inputs and media), and attaching the signed-in person id to server errors. Withdrawing consent stops replay without a reload.

The server side learns about consent from `consent:` in the reporting context (a decision hash or a list of categories) or `Current.consent`. Community Engine does not pass it yet, so until it does the person id is never attached.

## Content Security Policy

CE registers CSP sources globally, so the gem registers only the origins the environment implies for the host platform. A platform with its own client key and DSN must add the Sentry ingest origin (for example `https://o123.ingest.sentry.io`) to its platform CSP connect sources, and `https://js-de.sentry-cdn.com` to script sources, until CE supports platform-scoped registration. `CspSources.origins_for(platform)` gives the exact list.

## Development

```bash
bundle exec rake test      # unit tests (needs sentry-ruby)
BETTER_TOGETHER_CE_LIB=/path/to/community-engine-rails/lib bundle exec rspec   # cookie policy specs
bundle exec rubocop
```

The rspec suite uses Community Engine's shared examples (`better_together/cookie_policy/rspec`) and skips when they are not on the load path.

If you need more control, replace the registration in an initializer:

```ruby
BetterTogether.register_adapter(:error_reporting, :sentry) do |exception, context: {}|
  Sentry.capture_exception(exception, tags: { subsystem: 'ce' }, extra: context)
end
```

## License

LGPL-3.0-or-later, see `LICENSE`.
