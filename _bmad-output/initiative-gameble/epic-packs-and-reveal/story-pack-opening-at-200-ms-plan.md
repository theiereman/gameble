---
title: 'Pack opening at 200 ms'
type: 'feature'
ticket: '9'
created: '2026-10-02'
status: 'built'
baseline_revision: '4ddebaf7a8d5c4b6a3dbfa3c69c53496a8e77270'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/initiative-gameble/architecture-gameble/architecture-gameble.md', '{project-root}/_bmad-output/initiative-gameble/epic-packs-and-reveal/story-replacement-packs-and-the-timer-plan.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The spec asks pack opening to answer within 200 ms at the 95th percentile, and nothing measures it against a catalog of real size (epic 3, R4; Done when 6).

**Approach:** Add a repeatable benchmark that builds a 15,000-card published season and players with full banks in a database of its own, then times the opening request (the POST, the gate Done-when 6 means) and, as separate series, the result page GET and the operation alone; check that every opening succeeded; tune only what the figures show; record them in the epic Notes as a lower bound for production.

## Boundaries & Constraints

**Always:**
- `bin/rails game:benchmark_open_pack` (`packs/game/lib/tasks/game_benchmark.rake`) runs only with `Rails.env.test?`, on a database of its own (`gameble_benchmark`: the test config with that name; dropped if left over, created, schema loaded, connected; dropped in an `ensure`), and checks the connected database's name before any write; it aborts with a non-zero status otherwise.
- Representative settings in the task: `Rails.application.eager_load!`, Rails and Active Record loggers at `:info`, 50 discarded warm-up openings per series, the machine line (Ruby, YJIT, PostgreSQL host) printed.
- Seeding with `insert_all`: 15,000 cards (unique slug and source key, release date, image and store URLs), texts in both locales, card-seasons filling all five tiers (rarity 1–5, rating 0–100, prestige score), a published season numbered above any other; players (`steam_id`, `token`, `role`) in separate groups per series, banks filled with `Game::FillBank`, a few hundred holdings each; at most 10 openings per player.
- HTTP series: `require "action_dispatch/testing/integration"`; all sign-ins first through OmniAuth test mode (`mock_auth[:steam]` per player, as in `pages_controller_test.rb`), each checked, `test_mode` reset in an `ensure`; then the controller's cache store set to a `MemoryStore` so the rate limit runs (Solid Cache write not measured); each POST timed alone with `CLOCK_MONOTONIC` and its `Location` asserted to match `/packs/`; the GET that follows timed as its own series. Direct series: each `Game::OpenPack` asserted `Success`. Openings of both series interleaved.
- Report per series: count, mean, p50, p95, p99 (nearest rank), max, GC count, and queries per opening (from `sql.active_record`); plus the cold `DrawPool` build time on 15,000 rows; the whole run three times, the worst POST p95 kept; exit non-zero when it is ≥ 200 ms.
- `Game::DrawPool.warm` (rescues `StandardError`, logs a warning, returns nil) is called from an initializer at boot in server and jobs processes only (skipped in tests and rake tasks), kept only if the measured cold build exceeds 50 ms; tested directly (a raising query and no published season both return nil and leave no snapshot).
- If the POST p95 fails, tune in this order: the environment distortions, `EXPLAIN` on the slowest statement, merging `TopUpBank`'s count and maximum into one aggregate, event-store serialisation; an index only last (concurrently).
- The epic Notes gain the figures, the queries per opening, the machine line, and "in-process, no concurrency, dev machine: a lower bound for production".

**Never:** no change to the rules of opening, replacement or the draw; no benchmark in CI; no write to `gameble_test` or the development database.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Benchmark | 15,000 cards, players in groups, ≥ 1,000 timed openings per series | POST p95 < 200 ms on the dev machine; figures printed; exit 0 | — |
| A failed opening | an opening redirected home or a `Failure` | run aborted, not counted | abort |
| Wrong environment or database | `RAILS_ENV=development`, or a connection not to `gameble_benchmark` | refuses, writes nothing | non-zero exit |
| Crashed run | a previous run died midway | next run drops the leftover database first | — |
| Warm | boot with a published season / a raising query / no season | snapshot loaded / nil, no snapshot / nil | rescued |

## Code Map

- `packs/game/app/operations/game/open_pack.rb`, `app/models/game/{draw_pool,pack,top_up_bank}.rb`, `db/schema.rb` (indexes on `game_packs`, `game_holdings`), `config/database.yml` (test config to copy), `test/controllers/pages_controller_test.rb` (OmniAuth mock).
- `app/controllers/packs_controller.rb` (rate limit, redirect), `config/initializers/`.
- `packs/game/lib/tasks/game.rake` (3.2) -- where pack rake tasks live (Packwerk forbids `lib/` referencing Game).

## Tasks & Acceptance

**Execution:**
- [x] `packs/game/lib/tasks/game_benchmark.rake`.
- [x] `config/initializers/game_draw_pool.rb` -- not kept: the measured cold build is 25–34 ms, under the 50 ms bar (see Implementation Notes).
- [x] tuning as measured (indexes, queries), with tests kept green -- none needed (POST p95 9.3 ms).
- [x] epic Notes figures.

**Acceptance Criteria:**
- Given `RAILS_ENV=test bin/rails game:benchmark_open_pack` on the dev machine described in the Notes, when it runs, then the POST p95 is under 200 ms, the task exits 0, and the figures are recorded in the epic Notes.
- Given `bin/rails test`, `bundle exec packwerk check` and `bin/rubocop`, when run, then all pass.

## Implementation Notes

- The task is a plain class (`OpenPackBenchmark`) in the rake file, referenced only from the task block, so nothing in `Game` is autoloaded when rake loads the file. It refuses any environment but test, a database URL, and a connection whose `current_database()` is not `gameble_benchmark` (checked after connecting, before the schema load, before seeding and before each run). The database is dropped at the start (a crashed run's leftover) and in an `ensure`.
- Rate limit: `rate_limit` captures the controller's `cache_store` when the class body runs, so setting it after the sign-ins (as the Boundaries order it) would have no effect. The task sets `ActionController::Base.cache_store` to a `MemoryStore` before `eager_load!` (refusing if `PacksController` is already loaded) and, after each run, checks that the store counted exactly one hit per POST for every player, so the rate limit is proven to have run. Sign-ins are unaffected: Rack::Attack counts in `Rails.cache` (the test null store).
- Vite: the test configuration has `autoBuild`, which checks the build on every page; the task calls `ViteRuby.reload_with(auto_build: false)` as production serves prebuilt assets (also so the benchmark never rebuilds `public/vite-test` under a concurrent test run). It needs the existing test build.
- Queries per opening count `sql.active_record` events except `SCHEMA` and cached ones (BEGIN/COMMIT included). The POST's one more query than the operation is the player reload of `current_player`.
- Seeding: rarities come from `Catalog::RarityThresholds.tiers` on shuffled distinct scores (the publication's own cut, all five tiers), dust tiers from `Catalog::Dust.level_for`; 315 players per series group (105 per run, 10 openings each), banks by `Game::FillBank`, 300 holdings each, then `VACUUM ANALYZE`.
- `Game::DrawPool.warm` and `config/initializers/game_draw_pool.rb` were not added: the plan keeps them only if the cold build exceeds 50 ms, and it measured 25.4–33.6 ms over six runs. The first opening of each process pays that once. Story 3.2's note that "story 3.9 warms the pool at boot" no longer holds.
- Run time about 1.5 minutes.

## Plan Change Log

- Build (orchestrator, with the author's delegation to approve plans): the Boundaries said to set the rate-limit `MemoryStore` after the sign-ins; `rate_limit` captures `cache_store` when the controller class loads, so the store is set on `ActionController::Base` before `eager_load!`. Sign-ins are unaffected (Rack::Attack uses `Rails.cache`), and a per-player counter check after each run proves the limit ran. KEEP the counter check.

## Review Triage Log

### Pass 1 (quick) — high 0, medium 1, low 2, false 0, maybe-false 0

| # | Verdict | Route | Finding | Evidence / action |
|---|---|---|---|---|
| 1 | medium | patch | The DATABASE_URL refusal was dead code (Rails unpacks the URL before the task sees it), so the task could drop and create `gameble_benchmark` on another server | Confirmed in ActiveRecord 8.1's URL config. The task now refuses when `ENV["DATABASE_URL"]` is set. |
| 2 | low | patch | `pending-approvals.md` still promised a boot warm-up | Entry now states the measured cold build and that no warm-up was added. |
| 3 | low | patch | The rate-limit store order deviated from the Boundaries without a Plan Change Log entry | Recorded above. |


## Verification

**Commands:**
- `RAILS_ENV=test bin/rails game:benchmark_open_pack` -- expected: p95 < 200 ms.
- `bin/rails test && bundle exec packwerk check && bin/rubocop` -- expected: green.
