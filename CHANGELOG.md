# Changelog

All notable changes to this gem are recorded here. Format: Keep a Changelog, versioning: SemVer.

## [0.2.0]

### Added
- Per-platform settings through `BetterTogether.register_platform_setting`: server DSN (secret), browser client key, environment, traces sample rate, session replay opt-in, and attaching the signed-in person id. Values are validated; invalid ones read as unset. The `SENTRY_DSN`, `SENTRY_CLIENT_KEY`, `SENTRY_ENVIRONMENT` and `SENTRY_TRACES_SAMPLE_RATE` variables remain a fallback for the host platform only (applied by CE's registry).
- Consent and cookie policy: `:sentry` (essential, disclosure only, no cookies) and `:sentry_replay` (analytics) segments, shown only on platforms where they apply, plus a consent provider that asks for `analytics` only when replay or person identification is enabled.
- Browser script: init runs before the Sentry loader, with `sendDefaultPii: false`, no replay and no identity. Replay is lazy-loaded only after the visitor agrees to analytics (the `bt_consent` cookie at load, then `better_together:consent` events) and stops when they withdraw.
- Reporter reports to the Sentry project of the platform where the failure happened, with a separate client per DSN. A platform without a DSN reports nothing. Essential context only (request id, method, controller, action, path without query string); the person id is attached only when the platform enabled it and the person agreed to analytics. Email and IP addresses are never sent.
- `CspSources.origins_for(platform)` computes the exact CSP origins for one platform.
- LICENSE, CI workflow, Rakefile, Rubocop config, test and rspec skeletons.

- Private and protected pages stay essential-only. Session replay runs only while the page's `bt-third-party-tracking` meta tag is `on` (checked on load and on every `turbo:load`, and stopped when a visit reaches a private page). The reporter never attaches a person id when the error context has `private_page` set (CE sets it from its tracking exclusion rules). Errors are still reported, with request context only.

### Changed
- `SENTRY_DSN` is validated (https, key, project id); a malformed value no longer initialises Sentry.
- Boot-time CSP registration is limited to what the process environment implies for the host platform (CE registers CSP sources globally, not per platform).
- `send_default_pii` is explicitly false and events are scrubbed of email, username and IP address.

## [0.1.0]

- Initial gem: `:error_reporting` adapter, browser head tag provider, CSP origins and `SENTRY_DSN` bootstrap.
