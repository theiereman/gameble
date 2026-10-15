---
title: 'Sentry tells staging from production'
type: 'chore'
ticket: '53'
created: '2026-10-14'
status: done
baseline_revision: 'e5fd391d51d5150dcf71a04ee8cfd3078c98ed9e'
route: 'oneshot'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Staging runs with RAILS_ENV=production and `config/initializers/sentry.rb` sets the Sentry environment to `Rails.env`, so staging's errors and CSP reports reach Sentry labelled production and mix with production's.

**Approach:** The initializer takes the environment from `SENTRY_ENVIRONMENT`, falling back to `Rails.env`; `config/deploy.staging.yml` sets it to `staging` and `config/deploy.production.yml` to `production`. The CSP `report-uri` carries it through `Sentry.csp_report_uri`.

</frozen-after-approval>

## Verification

**Commands:**
- `bin/rails test test/initializers/sentry_test.rb` -- expected: the environment follows SENTRY_ENVIRONMENT and falls back to Rails.env
- `bin/ci` -- expected: green

**Manual checks (if no CLI):**
- After a staging deploy (author): a staging error and a staging CSP report reach Sentry under `staging`.

## Implementation Notes

Oneshot: three config lines and a test.

- `config/initializers/sentry.rb`: `SentryEnvironment.current` reads `SENTRY_ENVIRONMENT`, falling back to `Rails.env` (named `current`, since `name` would shadow `Module#name`); `config.environment` uses it.
- `config/deploy.staging.yml`, `config/deploy.production.yml`: `SENTRY_ENVIRONMENT` in `env.clear`.
- Checked by booting with a dummy DSN and `SENTRY_ENVIRONMENT=staging`: `Sentry.csp_report_uri` ends with `sentry_environment=staging`.

## Review Triage Log

### Pass 1 (quick, 2026-10-14) — high 0, medium 0, low 2, false 0, maybe-false 0

- `low` reject — the test checks `SentryEnvironment.current` but not that the initializer passes it to `config.environment`, since the suite runs without SENTRY_DSN; guarding the wiring needs a boot with a DSN in a subprocess, and the staging check in Verification covers it.
- `low` patch — `(AD-21)` planning ids left in the headers of `config/initializers/sentry.rb` and `config/deploy.staging.yml`, files this change touches; removed.
