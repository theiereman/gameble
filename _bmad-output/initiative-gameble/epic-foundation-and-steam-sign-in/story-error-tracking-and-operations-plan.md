---
title: 'Error tracking and operations'
type: 'feature'
ticket: '9'
created: '2026-10-02'
status: 'built'
baseline_revision: '63f5c20cb3c2274dc9145dd50a52ff1aa54edf8e'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Errors in production go nowhere, the sign-in endpoints can be hammered, and nobody can watch the job queue. AD-21 requires Sentry; the abuse convention requires rate limits; the spine's back-office starts with Mission Control Jobs, for administrators only.

**Approach:** Add `sentry-rails`, active only when `SENTRY_DSN` is set, with no personal data sent. Throttle the sign-in endpoints (`POST /auth/steam`, the callback and the failure endpoint) per client IP with Rack::Attack, because the request phase is OmniAuth middleware that no controller `rate_limit` can reach. Mount Mission Control Jobs under the back-office, behind a base controller that only administrators pass.

## Boundaries & Constraints

**Always:**
- Gems: `sentry-rails ~> 7.1.0` (Stack table), `mission_control-jobs ~> 1.3.1` (Stack table), `rack-attack ~> 6.8.0` (new; add a Stack row, AD-20).
- Sentry: DSN from `ENV["SENTRY_DSN"]` only; when it is absent, Sentry is not initialised and nothing is sent (development and test). `send_default_pii = false`; environment and release (from `KAMAL_VERSION` when present) set; filtered parameters follow `Rails.application.config.filter_parameters`. The player id may be attached as the Sentry user id; nothing else about the player.
- Kamal: `SENTRY_DSN` added to `config/deploy.yml` `env.secret` and to `.kamal/secrets` read from the deploying shell's environment (`SENTRY_DSN=$SENTRY_DSN`), never committed in clear.
- Rate limit: Rack::Attack throttles `POST /auth/steam` and `GET /auth/steam/callback` and `GET /auth/failure` per IP (10 requests per minute per IP across those paths); a throttled request gets 429 with a short plain-text body. It uses `Rails.cache`; tests use a memory store. Client IP is `request.ip` (Cloudflare's real-IP handling is deployment work).
- Mission Control Jobs: mounted at `/back-office/jobs` (outside the locale scope, engine routes); `config.mission_control.jobs.base_controller_class` is an app controller that requires an administrator through a Pundit policy; HTTP basic auth of the engine is off. A visitor is sent to sign in, a player or moderator gets 403 (story 1.7's refusal handling). The back-office dashboard links to it for administrators only.
- How to check Sentry on production is written in the README (hitl: the author creates the Sentry project, sets `SENTRY_DSN`, deploys, and triggers a test event).
- All copy in `en.yml` and `fr.yml`.

**Never:**
- No Sentry performance tracing or profiling sample rate above 0 (cost and noise); errors only.
- No custom job UI; no job of our own.
- No rate limit on reading pages.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| No DSN | `SENTRY_DSN` unset, app boots | Sentry not initialised; no event sent | No error expected |
| DSN set | `SENTRY_DSN` set, an exception in a request | the exception is reported to Sentry without PII | Normal error page |
| Sign-in under the limit | 10 sign-in requests from one IP in a minute | each handled normally | No error expected |
| Sign-in over the limit | 11th sign-in request from that IP within the minute | 429 | Throttled |
| Other IP | requests from another IP meanwhile | handled normally | No error expected |
| Page reads | many `GET /fr` from one IP | never throttled | No error expected |
| Jobs, administrator | `GET /back-office/jobs` as administrator | 200, the Mission Control dashboard | No error expected |
| Jobs, moderator or player | `GET /back-office/jobs` | 403 | Pundit refusal |
| Jobs, visitor | `GET /back-office/jobs` signed out | redirect to home with the sign-in alert | Pundit refusal |

</intent-contract>

## Code Map

- `app/controllers/application_controller.rb` -- Pundit (`pundit_user` = `current_player`), `verify_authorized` after every action, `current_player` with ban check, `rescue_from Pundit::NotAuthorizedError` (visitor → redirect to locale home with alert / 401 JSON; player → 403). A Mission Control base controller can inherit it (then authorize in a `before_action`; `verify_authorized` must be satisfied or skipped for the engine's actions) or inherit `ActionController::Base` and reproduce the check — choose the one that keeps one refusal path.
- `app/policies/application_policy.rb` -- `administrator?`; `app/policies/back_office/dashboard_policy.rb` (`show? = moderator?`) shows a headless policy.
- `app/controllers/back_office/dashboard_controller.rb`, `app/views/back_office/dashboard/show.html.erb` -- the empty back-office page; add the jobs link for administrators.
- `config/routes.rb` -- `/up`, OmniAuth routes (`/auth/steam/callback`, `/auth/failure`), `DELETE /session`, `scope ":locale"` with `home` and `back_office`; `root "locales#redirect"`.
- `config/initializers/omniauth.rb` -- the request phase `POST /auth/steam` is middleware (`OmniAuth::Builder`); Rack::Attack must sit before it in the middleware stack: insert it explicitly before `OmniAuth::Builder` and assert the order in a test.
- `config/environments/production.rb` -- Solid Queue adapter (`connects_to` queue database). Development and test use the default Active Job adapters; Mission Control needs a supported adapter to render its pages, so the administrator test may need `ActiveJob::Base.queue_adapter = :solid_queue` with the queue schema, or assert at the controller level that the request reaches the engine (200 or the engine's own page) — record what was done.
- `config/environments/test.rb` -- cache store `:null_store`.
- `config/deploy.yml` (`env.secret: [RAILS_MASTER_KEY]`), `.kamal/secrets` (`RAILS_MASTER_KEY=$(cat config/master.key)`).
- `test/fixtures/accounts/players.yml` -- `player`, `moderator`, `administrator`, `banned`; sign-in helpers in `test/controllers/sessions_controller_test.rb` / `authorization_test.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `Gemfile`, `Gemfile.lock`, `architecture-gameble.md` -- the three gems; Stack row for rack-attack
- [x] `config/initializers/sentry.rb` -- as in Always -- AD-21
- [x] `app/controllers/application_controller.rb` -- set the Sentry user id to the player id when Sentry is active -- useful context, no PII
- [x] `config/deploy.yml`, `.kamal/secrets` -- `SENTRY_DSN` secret -- production config
- [x] `config/initializers/rack_attack.rb`, `config/application.rb` (middleware) -- the sign-in throttle and its 429 response -- abuse convention
- [x] `config/initializers/mission_control.rb`, `app/controllers/back_office/jobs_base_controller.rb`, `app/policies/back_office/jobs_policy.rb`, `config/routes.rb` -- Mission Control mounted, administrators only -- R7
- [x] `app/views/back_office/dashboard/show.html.erb`, `config/locales/{en,fr}.yml` -- jobs link for administrators -- staff reach it
- [x] `README.md` -- production checks: set `SENTRY_DSN`, deploy, run `bin/kamal app exec 'bin/rails runner "Sentry.capture_message(%(gameble test event))"'` (or the sentry-ruby test task) and see it in Sentry -- hitl steps
- [x] tests: `test/initializers/sentry_test.rb` (no DSN → not initialised), `test/integration/rate_limit_test.rb` (matrix rows, cache swapped to a memory store and reset per test), `test/controllers/back_office/jobs_test.rb` and `test/policies/back_office/jobs_policy_test.rb` (every role, including the visitor) -- AD-22

**Acceptance Criteria:**
- Given no `SENTRY_DSN`, when the suite runs, then nothing is sent and Sentry is not initialised.
- Given one IP, when it sends 11 sign-in requests within a minute, then the 11th gets 429 and page reads are never throttled.
- Given each role, when it opens `/back-office/jobs`, then only the administrator gets in.
- Given the suite, when tests, system tests, Packwerk, i18n-tasks, RuboCop, zeitwerk, Brakeman and the type check run, then all pass.

## Implementation Notes

- Rack::Attack's railtie appends it to the middleware stack (and its env flag skips a second instance), so a plain `insert_before` would have run it twice. It is instead moved before OmniAuth::Builder with `config.middleware.move_before` at the end of `config/initializers/rack_attack.rb`, not in `config/application.rb`: the move must be recorded after `omniauth.rb` adds the builder. The order and the single instance are asserted in `test/integration/rate_limit_test.rb`.
- The 429 body is `rate_limit.throttled` in the default locale (the sign-in paths carry no locale); `config/initializers/` was added to i18n-tasks' search paths so the key counts as used.
- Sentry: besides `send_default_pii = false` (which in sentry-ruby 7.1 turns off request bodies, query strings, cookies and IP headers), a `before_send` filters any request data and query hash with `Rails.application.config.filter_parameters`. Checked with a fake DSN: initialised, release from `KAMAL_VERSION`, sample rates 0, filtered keys replaced by `[FILTERED]`. The Sentry user is set in a `before_action` of `ApplicationController`, only when Sentry is initialised and a player is signed in.
- Mission Control: `BackOffice::JobsBaseController < ApplicationController` authorizes `[:back_office, :jobs], :show?` in a `before_action`, which satisfies `verify_authorized` for every engine action and keeps the single refusal path. The refusal renders the app layout inside the engine, whose views only see engine routes, so the base controller adds `helper MissionControl::Jobs::HostRouteHelpers` (the gem's own delegation of host route helpers to `main_app`). Test and development have no Solid Queue, so the engine reads the async adapter and its dashboard renders 200 with no jobs; the administrator test asserts that page (title "Mission control").
- Engine links carry `?locale=en&server_id=…` because `ApplicationController#default_url_options` adds the locale; harmless, left as is.
- The jobs link is a full-page load (`data-turbo=false`), since the engine ships its own importmap layout: `ButtonComponent` links now honour `turbo: false` like its forms.

## Plan Change Log

## Review Triage Log

### 2026-10-02 — Review pass
- verdicts: 3 findings — high 0, medium 1, low 2, false 0, maybe-false 0
- findings:
  - `[medium]` `[patch]` The sign-in throttle compared paths case-sensitively while OmniAuth matches them case-insensitively, so `POST /AUTH/STEAM` and `/Auth/Steam/Callback` ran unthrottled — the path is lowercased before matching; a test mixes case variants into one limit.
  - `[low]` `[patch]` The README's `bin/kamal app exec` test command runs a fresh container without `KAMAL_VERSION`, so the event has no release — now `--reuse`.
  - `[low]` `[reject]` The plan's tests task was left unticked — the fix edits this build's plan; ticked as bookkeeping at finalize.

## Verification

**Commands:**
- `bin/rails test` -- expected: all green
- `CHROME_BIN=/usr/bin/chromium bin/rails test:system` -- expected: all green
- `bundle exec i18n-tasks missing` -- expected: none
- `bundle exec packwerk check && bin/rubocop && bin/rails zeitwerk:check && bin/brakeman -q --no-pager && bin/bundler-audit` -- expected: clean
- `bin/rails middleware | grep -n -E "Rack::Attack|OmniAuth"` -- expected: Rack::Attack listed before OmniAuth::Builder

## Auto Run Result

**Summary:** Sentry reports errors (no PII, no tracing) when `SENTRY_DSN` is set, with the player id as user and the Kamal version as release; Kamal passes the secret. Rack::Attack, placed before OmniAuth, throttles the sign-in paths to 10 requests a minute per IP (429 beyond). Mission Control Jobs is mounted at `/back-office/jobs` for administrators only, through the app's Pundit refusal path, and linked from the back-office.

**Files changed:**
- `Gemfile`, `Gemfile.lock`, `architecture-gameble.md` -- sentry-rails, mission_control-jobs, rack-attack (Stack row)
- `config/initializers/{sentry,rack_attack,mission_control}.rb` -- error tracking, throttle, engine config
- `config/deploy.yml`, `.kamal/secrets` -- `SENTRY_DSN` secret
- `config/routes.rb`, `app/controllers/back_office/jobs_base_controller.rb`, `app/policies/back_office/jobs_policy.rb` -- the jobs dashboard, administrators only
- `app/controllers/application_controller.rb` -- Sentry user id
- `app/views/back_office/dashboard/show.html.erb`, `app/components/button_component.*`, `config/locales/{en,fr}.yml`, `config/i18n-tasks.yml` -- jobs link, 429 copy
- `README.md` -- production checks
- `test/initializers/sentry_test.rb`, `test/integration/rate_limit_test.rb`, `test/controllers/back_office/jobs_test.rb`, `test/policies/back_office/jobs_policy_test.rb`, `test/components/button_component_test.rb`

**Review findings:** 2 patches applied (1 medium, 1 low); 0 deferred; 1 rejected (plan bookkeeping).

**Follow-up review recommended:** false — one medium patch.

**Verification:** `bin/rails test` (all green, including eager-loaded), system tests, i18n-tasks, Packwerk, RuboCop, zeitwerk, Brakeman, bundler-audit, typecheck clean; `bin/rails middleware` shows Rack::Attack once, right before OmniAuth::Builder.

**Residual risks:**
- hitl, owed by the author: create the Sentry project, export `SENTRY_DSN`, deploy, send the test event (README).
- Behind Cloudflare, `request.ip` is Cloudflare's unless real-IP handling is configured at deployment; until then all visitors share one sign-in limit.
- Mission Control's own assets in production are unverified until the first deploy. The 429 message is always English.
