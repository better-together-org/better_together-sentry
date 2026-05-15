# Better Together Sentry

Thin provider gem that registers Sentry adapters into the Better Together adapter registry.

## Purpose

This gem keeps Sentry out of the Community Engine gem while allowing host apps to opt in to:

- error reporting
- browser Sentry head tags
- future metrics/observability fan-out

## Usage

Add the gem to a CE host app and require it during boot.

```ruby
gem 'better_together-sentry', path: '../better_together-sentry'
```

The gem registers:

- an `:error_reporting` adapter named `:sentry` when `Sentry` is loaded
- a head-tag provider for the browser Sentry CDN script when `SENTRY_CLIENT_KEY` is present
- the related CSP origins for that browser script

## Configuration

The adapter sends exception context into Sentry `extra:`.

If you need more control, replace the registration in an initializer:

```ruby
BetterTogether.register_adapter(:error_reporting, :sentry) do |exception, context: {}|
  Sentry.capture_exception(exception, tags: { subsystem: 'ce' }, extra: context)
end
```
