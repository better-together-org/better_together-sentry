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
- a head-tag provider for the browser Sentry CDN script when `SENTRY_CLIENT_KEY` is present
- the related CSP origins for that browser script

## Configuration

Default bootstrap behavior:

- `SENTRY_DSN` enables initialization
- `GIT_REV` sets the Sentry release (left unset when blank so Sentry can auto-detect it)
- `breadcrumbs_logger` defaults to `[:active_support_logger, :http_logger]`
- `SENTRY_TRACES_SAMPLE_RATE` defaults to `0.05` (values outside 0..1 fall back to the default)
- `SENTRY_PROFILES_SAMPLE_RATE` defaults to `0` (profiling also needs stackprof or vernier)
- `SENTRY_TRACES_SAMPLER`: unset/`default` uses a parent-aware sampler that honours an upstream
  sampling decision and never traces `/healthcheck`, `/up`, `/assets`, `/cable`,
  `/rails/active_storage` or `/packs`; `always` traces every request (legacy); `disabled` uses
  only `SENTRY_TRACES_SAMPLE_RATE`
- `SystemExit` is excluded from error reports

These defaults match the values the NL Venues, Better Together and Newfoundland Labrador Online
host apps already set. The bootstrap runs after `config/initializers`, so a host app's own
`Sentry.init` wins.

The adapter sends exception context into Sentry `extra:`.

If you need more control, replace the registration in an initializer:

```ruby
BetterTogether.register_adapter(:error_reporting, :sentry) do |exception, context: {}|
  Sentry.capture_exception(exception, tags: { subsystem: 'ce' }, extra: context)
end
```
