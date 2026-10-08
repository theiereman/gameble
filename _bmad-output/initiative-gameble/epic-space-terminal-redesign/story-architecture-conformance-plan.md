---
title: 'Architecture conformance'
type: 'refactor'
ticket: '4'
created: '2026-10-05'
status: 'built'
baseline_revision: '3ba5bcf8289e6b5f6433f9190567c39b5cf0789c'
route: 'full'
route_source: 'auto'
review: 'thorough'
review_source: 'pinned'
lenses_ran: [blind-hunter, edge-case-hunter, verification-gap, intent-alignment]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred:
  - summary: >-
      The reading role opens a second connection pool to the primary, so a process can hold up to twice RAILS_MAX_THREADS primary connections.
    evidence: |-
      `connects_to database: { writing: :primary, reading: :primary }` gives each role its own pool; a GET leases from `reading` while the event store's ActiveRecord::Base models stay on `writing` (checked with bin/rails runner outside a test case). Transactional tests share the pools, so no test sees it. Postgres max_connections on the test LXC has not been checked against web, Solid Queue, Cache and Cable pools.
    location: >-
      lib/application_record.rb
    severity: low
  - summary: >-
      No test builds the CSP report-uri (Sentry) or the development Vite policy: both are decided at boot.
    evidence: |-
      `policy.report_uri -> { Sentry.csp_report_uri } if ENV["SENTRY_DSN"].present?` and the `vite` additions are evaluated once at boot; the suite runs without SENTRY_DSN in test. A dropped or broken line would ship green and the report-only release would collect nothing. Cheapest check: read the deployed response header once.
    location: >-
      config/initializers/content_security_policy.rb
    severity: medium
  - summary: >-
      Fonts under Vite's 4 KB inline limit become data: URIs, which font-src 'self' refuses once enforced.
    evidence: |-
      vite.config.ts assetsInlineLimit excludes only /images/card/; no font under 5 KB exists today (find app/frontend/fonts -size -5k is empty), but the redesign's subsetted woff2 files may fall under it.
    location: >-
      vite.config.ts, config/initializers/content_security_policy.rb
    severity: low (unverified)
  - summary: >-
      Mission Control Jobs' inline importmap scripts will send a report on every /back-office/jobs load during the report-only release.
    evidence: |-
      The engine layout calls javascript_importmap_tags (inline scripts) under script-src 'self'; administrators only, so the volume is small, but it adds noise to the reports the release exists to collect. Already listed among the violations to settle in deferred-work.md.
    location: >-
      app/controllers/back_office/jobs_base_controller.rb
    severity: low
---

<intent-contract>

## Intent

**Problem:** The built code contradicts the updated spine (AD-28's conformance list): jobs enqueue inside transactions, there is no `reading` role and GETs may write the primary, the daily bonus ignores the reserve cap of 10, `game_player_states` does not exist, and no Content-Security-Policy is sent.

**Approach:** Five small, independent alignments: `enqueue_after_transaction_commit` on every job; the `reading` role declared on `ApplicationRecord` (pointing to the primary) and every GET/HEAD of `ApplicationController` run on it with writes prevented, the Steam callback exempt; one `Game::Reserve` query read by `Game::CollectDailyBonus` (`reserve_full` at 10) and `Game::BankSummary`; the `game_player_states` table with a creation path at registration and a per-player backfill job; a report-only CSP per AD-27.

## Boundaries & Constraints

**Always:** AD-3 (writes only through operations; handlers call operations), AD-10 lock order (bank lock, then holdings, then `game_player_states`), AD-14 (many-player work = a job running a per-player operation, one transaction each), AD-21 (`strong_migrations` passes), copy in "vous" in fr and en (AD-18), tests run on one `DATABASE_URL` (no new entry in `config/database.yml`).

**Never:** no NOUVEAU watermark, active back, presence or activity columns; no new screen or restyle (the attic keeps its look); no `DatabaseSelector` middleware or role switch on `ActiveRecord::Base` (it would block Solid Queue and Solid Cache writes); no CSP enforcement yet; no inline script added anywhere.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Bonus, reserve < 10 | 9 available packs (any kind), unclaimed today | bonus pack created, 10 available | none |
| Bonus, reserve full | 10 available packs (e.g. a full bank) | `Failure(:reserve_full)`; no claim, pack or event | flash `errors.game.reserve_full` |
| Bonus, no bank yet | 0 packs, season published | reserve read before the fill: bank filled + bonus (11) | none |
| Bonus, claimed + full | already claimed today, reserve 10 | `Failure(:already_collected)` (checked first) | flash |
| GET writes | a GET action creating a row | `ActiveRecord::ReadOnlyError` raised | none (programming error) |
| Steam callback | GET `/auth/steam/callback` | signs in as before (exempt) | unchanged |
| Rolled-back enqueue | `perform_later` inside a transaction that rolls back | nothing enqueued | none |
| Backfill | players with and without a row, banned included | every player has exactly one row; rerun is a no-op | a failing player reported and skipped |

</intent-contract>

## Code Map

- `lib/application_record.rb` -- `primary_abstract_class`; add `connects_to database: { writing: :primary, reading: :primary }`. Verified: switching `ApplicationRecord.connected_to(role: :reading, prevent_writes: true)` raises `ReadOnlyError` on writes from `ApplicationRecord` models and from `ActiveRecord::Base` models (Rails Event Store) but not from `SolidQueue::Record`/`SolidCache::Record` (own connection classes).
- `app/controllers/application_controller.rb` -- add the role around_action FIRST (before `switch_locale`) so `current_player` loads inside it.
- `app/controllers/sessions_controller.rb` -- `create` is the GET callback that writes (`Accounts::SignIn`): skip the around_action for `create` only; `failure` and `destroy` keep defaults.
- `config/initializers/` -- new `active_job.rb`: `ActiveSupport.on_load(:active_job) { self.enqueue_after_transaction_commit = true }` (pack jobs inherit `ActiveJob::Base`, not `ApplicationJob`; Rails 8.1 removed the global config). Turbo/Mailer jobs covered too.
- `packs/game/app/handlers/game/handlers/season_published.rb` -- drop `ActiveRecord.after_all_transactions_commit`, plain `HealBanksJob.perform_later`.
- `packs/game/app/queries/game/bank_summary.rb` -- `available` from the new `Game::Reserve`, new key `reserve_full`; `bonus_collectable` unchanged (season + unclaimed).
- `packs/game/app/operations/game/collect_daily_bonus.rb` -- order: `unclaimed` → `published_pool` → reserve check (before `FillBank`) → fill → bonus.
- `packs/game/app/models/game/pack.rb` -- `available(now)` scope is the reserve's query basis; `BANK_SIZE` is a different concept (regular, scheduled included).
- `packs/game/app/handlers/game/handlers/player_registered.rb` -- after `FillBank`, call the new create operation (lock order).
- `packs/game/app/jobs/game/heal_banks_job.rb`, `packs/game/lib/tasks/game.rake` -- pattern for the backfill job and rake task (but the new task must run in production).
- `packs/accounts/app/queries/accounts/players_in_batches.rb` -- skips banned players; add `include_banned: false` keyword.
- `packs/game/app/models/game/bank_lock.rb` -- update the lock-order comment to AD-10's three steps.
- `config/initializers/content_security_policy.rb` -- all commented out today; `csp_meta_tag` already in `app/views/layouts/application.html.erb`. Images use `<img crossOrigin="anonymous">` (`packages/pixel-art-filter/src/render-art.ts`), host `Steam::Cdn::ASSET_BASE` (`packs/steam/app/clients/steam/cdn.rb`); Vite may inline small assets as `data:`.
- `app/views/pages/home.html.erb` -- attic bonus panel (`bonus_panel` local, line ~67).
- Tests to adapt: `test/packs/game/collect_daily_bonus_test.rb` (full-bank collections and the "pile up above ten" test now contradict AD-7), `test/packs/game/queries_test.rb`, `test/packs/game/top_up_bank_test.rb`, `test/system/daily_bonus_test.rb` (fills a full bank then collects), `test/controllers/daily_bonuses_controller_test.rb`.

## Tasks & Acceptance

**Execution:**
- [x] `lib/application_record.rb` -- declare the reading role pointing to `:primary` -- AD-11, a replica later is `reading: :primary_replica`.
- [x] `app/controllers/application_controller.rb`, `app/controllers/sessions_controller.rb` -- GET/HEAD run inside `ApplicationRecord.connected_to(role: :reading, prevent_writes: true)`; exempt `sessions#create` with a comment -- AD-11.
- [x] `config/initializers/active_job.rb`, `season_published.rb` -- enqueue after commit everywhere; simplify the handler -- AD-13.
- [x] `packs/game/app/queries/game/reserve.rb` (new) -- `Game::Reserve::FULL = 10`, `count(player_id, now:)` (unopened packs of any kind with `available_at <= now`) and `full?(count)` -- AD-7 "one query".
- [x] `bank_summary.rb`, `collect_daily_bonus.rb`, `config/locales/{en,fr}.yml`, `home.html.erb` -- `reserve_full` failure and summary key; locale `errors.game.reserve_full` (fr "Votre réserve est pleine : ouvrez un booster pour récupérer celui du jour.", en "Your reserve is full: open a booster to collect today's."); the attic panel shows that message instead of its button when `@bank[:reserve_full]` -- AD-7.
- [x] `db/migrate/<ts>_create_game_player_states.rb`, `db/schema.rb` -- `game_player_states`: `player_id` bigint not null, unique index, FK to `accounts_players`, timestamps; nothing else.
- [x] `packs/game/app/models/game/player_state.rb`, `packs/game/app/operations/game/create_player_state.rb` -- model; operation inserting the row with `ON CONFLICT DO NOTHING` for any persisted player (banned included: own check, not `require_player`), publishes no event (housekeeping, AD-10), returns `Success(state)` / `Failure(:player_required)`.
- [x] `player_registered.rb` -- create the state after `FillBank`.
- [x] `packs/game/app/jobs/game/backfill_player_states_job.rb`, `game.rake` task `game:backfill_player_states` (allowed in production), `players_in_batches.rb` -- per batch skip players with a row, one operation per player, failures reported and skipped -- AD-14.
- [x] `test/fixtures/game/player_states.yml` -- one row per fixture player (`player_id: <%= ActiveRecord::FixtureSet.identify(:player) %>`).
- [x] `config/initializers/content_security_policy.rb` -- report-only policy (Design Notes).
- [x] Tests -- new: read-only GET probe (with_routing + probe controller: GET write raises `ReadOnlyError`, POST write succeeds, GET enqueue allowed, GET runs on `:reading`); enqueue after commit (rollback → nothing; commit → enqueued only after); `Game::Reserve` and the `reserve_full` failure (writes nothing, publishes nothing); create-state operation, handler (new player has a row), backfill job (every player incl. banned, idempotent); CSP header (report-only header present, enforced header absent, directives per Design Notes, `wss://` from `config.x.public_url`); daily-bonus controller/system full-reserve case. Adapt the tests listed in the Code Map.
- [x] `_bmad-output/initiative-gameble/pending-approvals.md`, `deferred-work.md` -- run `game:backfill_player_states` on the test LXC after deploying; CSP enforcement follow-ups.

**Acceptance Criteria:**
- Given any GET or HEAD served by `ApplicationController` except the Steam callback, when its code writes an `ApplicationRecord` or event-store row, then the request raises `ActiveRecord::ReadOnlyError`; the full existing suite passes under this guard.
- Given a page request, when the response arrives, then it carries `Content-Security-Policy-Report-Only` and no `Content-Security-Policy`.
- Given every player at backfill time, when `game:backfill_player_states` has run, then each has exactly one `game_player_states` row; a player registering afterwards gets one in the sign-up transaction.

## Implementation Notes

- **Reading role.** `ApplicationRecord.connects_to database: { writing: :primary, reading: :primary }` works with the single-config test database (its name is `primary`) and with transactional tests (Rails shares the writing pool with the reading role). The around_action `read_only_unless_writing` is declared first in `ApplicationController`; `SessionsController` skips it for `create` only. The probe test (`test/controllers/read_only_requests_test.rb`) confirms GET and HEAD writes from an `ApplicationRecord` model and from the event store raise `ReadOnlyError`, a POST writes, the role is back to `:writing` after the request. The whole existing suite (1,014 tests then) passed under the guard with no change: no GET wrote.
- **Enqueue after commit.** `config/initializers/active_job.rb` sets it on `ActiveJob::Base` in `on_load(:active_job)`; the test checks the packs' jobs, `ApplicationJob`, `ActionMailer::MailDeliveryJob` and `Turbo::Streams::BroadcastJob` inherit it. Transactional tests behave: a job enqueued in `ApplicationRecord.transaction` leaves at its commit, none on rollback.
- **GET enqueue** is proven only on the `:test` adapter (no Solid Queue database in test); recorded in `deferred-work.md`.
- **Reserve.** `Game::Reserve.count` reads `Pack.where(player_id:).available(now).count` (Rails drops the scope's order for a count). `Game::BankSummary` gains `reserve_full`; the hash key order is `available, reserve_full, next_available_at, bonus_collectable`.
- **Attic panel.** A first version put the message in a second text plate below the first; its font came out larger than the panel's text. It is now a second `attic__bonus-text` paragraph inside the existing plate, and the button is left out (screenshot checked). No CSS changed.
- **Surprise: a new player's attic.** A new player's ten packs are all available, so the reserve is full at once and the bonus panel shows the message instead of "Take it" until they open a pack. `test/system/signed_out_attic_test.rb` asserted "Take it" right after enlisting; it now asserts the message. Recorded for the author's confirmation in `pending-approvals.md`.
- **Tests adapted for the cap.** `collect_daily_bonus_test.rb`: the full-bank collection became a reserve of nine (full bank, one opening); "pile up above ten" became "fill the reserve up to ten, then wait for an opening" (still checks the countdown does not move); the UTC-day test opens two packs between its two days. Added: full reserve refused with no claim, pack or event; the reserve counts every kind and leaves scheduled and opened packs out; `already_collected` wins over `reserve_full`. `collect_daily_bonus_concurrency_test.rb` starts from nine packs (ten would refuse both threads with `reserve_full`). Controller and system daily-bonus tests start from nine packs and gained a full-reserve case.
- **Player states.** `Game::CreatePlayerState` uses `PlayerState.insert(..., unique_by: :player_id)` (ON CONFLICT DO NOTHING) then reads the row, in a transaction; it checks persisted-player itself so banned players qualify. `Accounts::PlayersInBatches` gained `include_banned:`. The backfill job reads which players of a batch have a row in one query (two queries per batch in all). `game:backfill_player_states` has no production guard. The fixture file lists the four fixture players explicitly.
- **Migration.** `20261005000000_create_game_player_states.rb` passed `strong_migrations`; `db/schema.rb` regenerated by `db:migrate` on the worker test database (version `2026_10_05_000000`).
- **CSP deviation (nonce generator).** The plan's `->(request) { request.session.id.to_s }` gives an empty, invalid `'nonce-'` when the session has not been loaded when the nonce is read: always in the test environment (no CSRF meta tags, which in production load the session before `csp_meta_tag`), and on responses that never touch the session. The generator falls back to `SecureRandom.base64(16)` for that request only; with a session it is still the session id, stable across Turbo visits (tested).
- **CSP construction.** `policy.script_src` with no argument deletes the directive in Rails 8.1 (no getter), so the development additions are built as arrays before the block. Steam hosts and the cable origin are procs (no autoload at boot, `config.x.public_url` read per request); a nil cable origin adds nothing. `report-uri` is a proc to `Sentry.csp_report_uri`, set only when `SENTRY_DSN` is present (Sentry initialises after this file). The development policy was checked by building it under `RAILS_ENV=development` (Vite at `localhost:3036`, no nonce directive).
- **Steam constant.** `Steam::Cdn::IMAGE_SOURCES = %w[https://*.steamstatic.com]` (an array, splatted by the policy).
- **Review fixes.**
  - The `SessionsController` comment now says the Steam return reaches the app as a POST in production (rack-openid relabels it with `_method=post`), so the skip only matters under OmniAuth test mode.
  - The `ApplicationRecord` comment says a replica also needs the reads that follow a write kept on the primary.
  - With a full reserve, the attic panel shows the reserve sentence in place of "A small booster awaits you" (one paragraph), so the two no longer contradict each other.
  - `game:benchmark_open_pack` re-points both roles (`ApplicationRecord.connects_to(database: { writing: db_config, reading: db_config })`), and `check_database!` checks the reading role too. A runner script on a throwaway database confirmed both roles resolve to it, before and after `load_schema`.
  - `game:backfill_player_states` prints a success line, or aborts with the count of players still without a row (`Game::BackfillPlayerStatesJob.players_without_a_row`). Both outcomes are tested.
- **Verification.** RuboCop, packwerk validate and check, i18n-tasks missing (and unused), Brakeman, `npm run typecheck`, `npm run test:js` (60), `bin/rails test` (1,042 runs) and `bin/rails test:system` (47 runs) all pass on `gameble_test_w84`.

## Plan Change Log

## Review Triage Log

### 2026-10-05 — Review pass
- verdicts: 29 findings — high 0, medium 5, low 12, false 11, maybe-false 1
- findings:
  - `[false]` `[reject]` (blind) The Steam-callback exemption contradicts its comment; in production rack-openid relabels the return as POST — real, see next row; the exemption itself is harmless.
  - `[low]` `[patch]` (blind) The sessions comment calls the callback "the one GET" that writes; rack/openid.rb:158-172 and 243 relabel it POST in production — comment reworded: POST through Steam, a real GET only under OmniAuth test mode, which the skip covers.
  - `[low]` `[patch]` (blind) The ApplicationRecord comment presents a replica as only `reading: :primary_replica`, but reads right after a write would go stale — comment now says those reads must stay on the primary.
  - `[low]` `[defer]` (blind) The reading role doubles primary pools per process; sizing never checked — recorded in `deferred` and deferred-work.md.
  - `[false]` `[reject]` (blind) The guard has no report-first phase, so an untested writing GET becomes a 500 — the intent requires GETs with writes prevented; the verification-gap lens and the full suite found no GET that writes; Mission Control's GETs read Solid Queue's own connection class.
  - `[low]` `[patch]` (blind) With a full reserve the panel said "a booster awaits you" above "your reserve is full" — the reserve sentence now replaces the panel text; the tu/vous mix of the old attic copy is the shell and hub stories' rewrite to "vous" (AD-18).
  - `[low]` `[reject]` (blind) After a refused POST the reserve sentence shows twice (flash and panel) — only reachable from a stale tab, since the button is gone when full; one locale key for one sentence is AD-18's single place for copy.
  - `[low]` `[defer]` (blind) Mission Control will send CSP reports on every jobs page load — administrators only; recorded in `deferred`, already among the violations in deferred-work.md.
  - `[medium]` `[defer]` (blind) The development policy and the Sentry report-uri are built at boot and never tested — grouped with the verification-gap finding below; recorded in `deferred`.
  - `[false]` `[reject]` (blind) The plan is stale (nonce Design Note, empty triage log, matrix row "11" against the adapted test) — the triage log is written at this step; the "11" row matches "a player without a bank gets ten regular packs … then the bonus" (10 regular + 1 bonus), not the "bank that is not full" test cited; the nonce deviation is recorded in Implementation Notes; fixing it would edit this build's plan.
  - `[medium]` `[patch]` (blind) The backfill is a manual step with nothing to show a missed or partial run — grouped with the edge-case finding on skipped players: `game:backfill_player_states` now prints success or aborts with the count of players still without a row (`players_without_a_row`), both outcomes tested; running it on the LXC stays in pending-approvals.md.
  - `[false]` `[reject]` (blind) The cable origin comes from PUBLIC_URL, which could carry a path or another host — `PublicUrl.parse` refuses any path, and no cable URL or host other than the public one is configured; Turbo's cable is same-origin `/cable`.
  - `[medium]` `[defer]` (verification-gap) No test builds the report-uri to Sentry; a broken line ships green — recorded in `deferred` (check the deployed header once).
  - `[low]` `[defer]` (verification-gap) A GET can hold one connection from each pool outside tests — same root cause as the pool row above; recorded in `deferred`.
  - `[medium]` `[patch]` (edge-case) `game:benchmark_open_pack` re-pointed only Base's writing pool, so its timed GET read the test database under the reading role — `ApplicationRecord.connects_to(database: { writing: db_config, reading: db_config })` and `check_database!` checks both roles; the full benchmark ran: worst POST p95 11.1 ms, GET pages 200.
  - `[low]` `[defer]` (edge-case) Pool doubling may exhaust Postgres connections — same root cause as the pool row; recorded in `deferred`.
  - `[maybe-false]` `[defer]` (edge-case) Fonts under 4 KB inlined as data: break font-src 'self' — no font under 5 KB exists today; would settle by checking the redesign's subsetted fonts against `assetsInlineLimit`; recorded in `deferred` as low (unverified).
  - `[low]` `[reject]` (edge-case) An invalid SENTRY_DSN makes `Sentry.csp_report_uri` nil and leaves an empty report-uri — browsers ignore an empty directive; nothing is blocked in report-only; a guard adds a branch for a misconfiguration Sentry itself already logs.
  - `[medium]` `[patch]` (edge-case) The backfill task reports no skipped players — grouped with the blind backfill row above; same fix.
  - `[false]` `[reject]` (intent) The job test proves "never enqueued", not "never runs" — a job never enqueued cannot run; deferral happens before the adapter is called, whatever the adapter.
  - `[false]` `[reject]` (intent) The Steam-callback exemption leaves a GET that writes — in production the callback reaches Rails as a POST (rack-openid), so no real GET writes; the exemption covers only the test-mode GET.
  - `[low]` `[defer]` (intent) Production's separate reading pool is not exercised — same root cause as the pool row; recorded in `deferred`.
  - `[false]` `[reject]` (intent) A player with no bank ends with 11 available packs, so the cap is not an invariant — AD-7 refuses the claim "while it holds 10", which this reads at the claim; recorded for confirmation in pending-approvals.md.
  - `[false]` `[reject]` (intent) A new player cannot take the bonus until they open a pack — AD-7's direct consequence (ten packs available at once), matching EXPERIENCE.md's "Réserve pleine" first-session journey; recorded for confirmation in pending-approvals.md.
  - `[low]` `[reject]` (intent) The new copy says "vous" beside "tu" strings — AD-18 says copy uses "vous"; the old strings move with the shell and hub stories.
  - `[false]` `[reject]` (intent) The backfill is never run on real data — running it is an operation on a deployed host, queued in pending-approvals.md as the rules require; the rake task now fails loudly on a partial run.
  - `[false]` `[reject]` (intent) "Every fixture player has their row" proves no code path — the backfill job test asserts every player (banned and a newcomer included) has a row after the job; the fixture test only checks the fixtures.
  - `[low]` `[reject]` (intent) Players created other than through SignIn get no row — players are created only by `Accounts::SignIn` (AD-14: Steam sign-in only); direct `create!` exists only in tests; the backfill catches any other.
  - `[false]` `[reject]` (intent) Only two pages are tested for the CSP header — the policy is app-wide middleware configuration; the header does not depend on the page.

## Design Notes

CSP (AD-27), all environments report-only (`config.content_security_policy_report_only = true`, enforcement after one release):
- production and test: `default-src 'self'; base-uri 'self'; object-src 'none'; script-src 'self'; style-src 'self' 'nonce-…'; img-src 'self' data: <steam>; font-src 'self'; worker-src 'self' blob:; connect-src 'self' <steam> <cable>`.
- `<steam>` = `Steam::Cdn::IMAGE_SOURCES` (new constant, `https://*.steamstatic.com`), read in a proc (no autoload at boot); `<cable>` = proc from `Rails.configuration.x.public_url` with `http`→`ws` (nil → nothing).
- nonce generator `->(request) { request.session.id.to_s }` (stable across Turbo visits, the Rails default); `content_security_policy_nonce_directives = %w[style-src]`, `[]` in development.
- development adds the Vite dev server (`ViteRuby.config.host_with_port`): `'unsafe-inline' 'unsafe-eval' http://<vite>` to script-src (React refresh preamble), `'unsafe-inline' http://<vite>` to style-src, `ws://<vite> http://<vite>` to connect-src.
- `report-uri` → `Sentry.csp_report_uri` (proc) only when `SENTRY_DSN` is set.
- Mission Control Jobs uses inline importmap scripts: a violation in report-only, deferred to the enforcement step.

Reserve before fill: the page shows the reserve as it stands (0 for a player without a bank), so the operation reads it at the same point.

## Verification

**Commands (all with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w84`):**
- `bin/rubocop` -- no offenses
- `bundle exec packwerk validate && bundle exec packwerk check` -- no violations
- `bundle exec i18n-tasks missing` -- none
- `npm run typecheck && npm run test:js` -- pass
- `bin/rails test` and `bin/rails test:system` -- pass

## Auto Run Result

**Status:** built.

**Summary:** brings the built code in line with AD-28's conformance list (R7):
- every job is enqueued only after its transaction commits (`enqueue_after_transaction_commit` on `ActiveJob::Base`);
- the `reading` role is declared on `ApplicationRecord`, pointing to the primary, and every GET and HEAD of `ApplicationController` runs on it with writes prevented;
- the reserve is one query (`Game::Reserve`), read by the chest and by `Game::CollectDailyBonus`, which refuses with `reserve_full` at 10;
- the `game_player_states` table is created, with a row made at sign-up and a backfill job and task;
- a report-only Content-Security-Policy follows AD-27.

**Files changed:**
- `lib/application_record.rb`: the `reading` role, pointing to the primary.
- `app/controllers/application_controller.rb`: the `read_only_unless_writing` around_action.
- `app/controllers/sessions_controller.rb`: the test-mode GET callback is exempt from it.
- `config/initializers/active_job.rb` (new): enqueue after commit.
- `packs/game/app/handlers/game/handlers/season_published.rb`: a plain `perform_later`.
- `packs/game/app/queries/game/reserve.rb` (new): the reserve query, and `FULL = 10`.
- `packs/game/app/queries/game/bank_summary.rb`: new `reserve_full` key.
- `packs/game/app/operations/game/collect_daily_bonus.rb`: the `reserve_full` failure.
- `config/locales/en.yml`, `config/locales/fr.yml`: `errors.game.reserve_full`.
- `app/views/pages/home.html.erb`: with a full reserve, the attic panel shows the reserve sentence and no button.
- `db/migrate/20261005000000_create_game_player_states.rb`, `db/schema.rb`: the table.
- `packs/game/app/models/game/player_state.rb`: the model.
- `packs/game/app/operations/game/create_player_state.rb`: the idempotent create.
- `packs/game/app/handlers/game/handlers/player_registered.rb`: creates the row after the bank.
- `packs/game/app/jobs/game/backfill_player_states_job.rb`, `packs/game/lib/tasks/game.rake`: the backfill job and `game:backfill_player_states`.
- `packs/accounts/app/queries/accounts/players_in_batches.rb`: `include_banned:`.
- `packs/game/app/models/game/bank_lock.rb`: AD-10's lock order in the comment.
- `config/initializers/content_security_policy.rb`: the report-only policy.
- `packs/steam/app/clients/steam/cdn.rb`: `IMAGE_SOURCES`.
- `packs/game/lib/tasks/game_benchmark.rake`: both roles re-pointed to the benchmark database.
- Tests:
  - new: `test/controllers/read_only_requests_test.rb`, `test/initializers/active_job_test.rb`, `test/integration/content_security_policy_test.rb`, `test/packs/game/player_state_test.rb` and `test/fixtures/game/player_states.yml`;
  - adapted: the daily bonus tests (operation, concurrency, controller, system), the queries and top-up tests, the sessions test and the signed-out attic test.
- `_bmad-output/initiative-gameble/pending-approvals.md`, `deferred-work.md`: follow-ups.

**Review (thorough, 4 lenses, 29 findings):**
- 5 patches (entry verdicts: 2 medium, 3 low):
  - the sessions comment;
  - the replica comment;
  - the panel text;
  - the benchmark's reading role;
  - the backfill task, which now fails with a count when players are left without a row.
- 4 deferred items (frontmatter `deferred`, mirrored in deferred-work.md):
  - the doubled connection pools;
  - no test of the report-uri or of the development policy;
  - small fonts that Vite may inline as data: URIs;
  - CSP reports from Mission Control.
- 20 rejected; each reason is recorded in the Review Triage Log.

**Follow-up review recommended:** false. Two medium entries were patched, and both are verified:
- the full `game:benchmark_open_pack` ran on the patched code: worst POST p95 11.1 ms, every GET page answered 200;
- both outcomes of the backfill task are tested.

No unverified risk can be named.

**Verification**, all on `gameble_test_w84` and all passing:
- `bin/rubocop`: no offenses.
- `packwerk validate` and `packwerk check`: no violations.
- `i18n-tasks missing`: none.
- `npm run typecheck` and `npm run test:js`: 60 tests.
- `bin/rails test`: 1043 runs, 0 failures.
- `bin/rails test:system`: 47 runs, 0 failures.

**Residual risks:**
- The backfill has not been run on the test LXC (pending approval).
- A new player cannot take the daily bonus before opening a pack. This is AD-7's consequence, pending the author's confirmation.
- The CSP has not been enforced; enforcement is deferred.
- Connection-pool sizing has not been checked on the LXC.
