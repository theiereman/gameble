---
title: 'The wanted refresh after an event runs in a job'
type: 'refactor'
ticket: '22'
created: '2026-11-23'
status: 'built'
baseline_revision: '6a3d65a734bc1a388ed551ce8667599d4dc37448'
route: 'oneshot'
route_source: 'auto'
review: 'none'
review_source: 'pinned'
lenses_ran: []
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** `WantedRefresh` runs `RefreshWanted` inside every listed event's transaction, so a pack opening (and every order, sale, purchase and slot publisher) pays the refresh in its request; the author measured it against `POST /packs`' 200 ms p95 and moved it out (AD-61, amended 2026-11-20).

**Approach:** The handler enqueues, after commit, `Game::Market::RefreshWantedJob` once per player the event names, skipping removed players and any player whose refresh is already pending; the job runs `Game::Market::RebuildWanted(player:)`, which takes the bank lock, clears the player's pending mark and calls `RefreshWanted`. A pending mark is one row of a new `game_market_pending_wanted_refreshes` table (unique on player), inserted `ON CONFLICT DO NOTHING` by the handler inside the event's transaction: only a newly inserted mark enqueues a job. `ReleasePlayer`'s clear, the season rebuild and the unban rebuild stay as they are.

</intent-contract>

## Implementation Notes

Oneshot: about 50 lines of application code (one migration, one model, the handler, one job, one line each in `RebuildWanted` and `ReleasePlayer`) plus tests.

- Dedup lives in the primary database, not in Solid Queue: the queue is its own database in production and the `:test` adapter in tests, and Solid Queue's `limits_concurrency ... on_conflict: :discard` would also discard while a job runs, losing a change committed after that job read. The mark is cleared under the player's bank lock, before `RefreshWanted` reads, and every publisher of the heard events holds that lock while publishing: an event either commits before the job takes the lock (the job reads it) or after the job commits (its mark is new and enqueues a job).
- The migration is timestamped before the wanted rebuild data migration (`20261123100001`), because that migration runs `RebuildWanted`, which now deletes from the new table.
- Files: migration `20261123095000_create_game_market_pending_wanted_refreshes.rb`, `db/schema.rb`; model `pending_wanted_refresh.rb` (`mark` returns the newly marked ids); job `refresh_wanted_job.rb`; `wanted_refresh.rb` (players in good standing, marked, one job each); `rebuild_wanted.rb` and `release_player.rb` clear the mark; `event_store.rb` comment; tests: new `refresh_wanted_job_test.rb`; `wanted_refresh_test.rb` drains the refresh jobs before reading rows (two tests now drain after `aim`, since a refresh run after a ban or a goal deletion reads the later state); `wanted_notices_test.rb`, `market_wanted_cards_test.rb`, `wanted_card_notice_job_test.rb` drain after the goal or order they set up; `accounts_controller_test.rb` names the new table in the delete dialog list ("vos objectifs").
- Surprise: tests that commit for real (`use_transactional_tests = false`) now leave marks, which broke fixture loading (FK to players they delete) and would stop a later test's refresh from being queued. `test/test_helper.rb` clears the marks in `before_teardown` of such tests, ahead of their own teardowns.
- Not run here: `bin/rails game:benchmark_open_pack`, whose fixed `gameble_benchmark` database the parallel builds share; the orchestrator runs it. The opening's request now pays one `INSERT ... ON CONFLICT DO NOTHING` per named player instead of the refresh.
- Residual risk: a mark left by an enqueue that fails after commit blocks that player's refreshes until the next `RebuildWanted` for them (season publish, unban, deploy rebuild).

## Verification

**Commands:**
- `RAILS_ENV=test DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_schema_a SCHEMA=tmp/migrated_schema.rb bin/rails db:drop db:create db:migrate && cp tmp/migrated_schema.rb db/schema.rb` -- expected: only the new table in the diff
- `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_a PARALLEL_WORKERS=4 bin/rails test test/domains/game/market test/controllers/market_wanted_cards_test.rb test/controllers/accounts_controller_test.rb test/domains/game/goals_reached_test.rb test/domains/game/achievements_test.rb test/jobs/wanted_card_notice_job_test.rb` -- expected: green
- `bin/rails zeitwerk:check`, `bundle exec packwerk check`, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec rubocop` on touched files -- expected: pass
- `RAILS_ENV=test bin/rails game:benchmark_open_pack` -- left to the orchestrator (its `gameble_benchmark` database is shared by the parallel builds)

## Auto Run Result

- **Summary:** the `WantedRefresh` handler no longer refreshes inside the event's transaction: it marks each named player in good standing in `game_market_pending_wanted_refreshes` (`ON CONFLICT DO NOTHING`) and queues, after commit, one `Game::Market::RefreshWantedJob` per newly marked player; the job runs `RebuildWanted`, which takes the bank lock, clears the mark and calls `RefreshWanted`. `ReleasePlayer`'s clear (now also of the mark), the season rebuild and the unban rebuild are unchanged.
- **Files:** `db/migrate/20261123095000_create_game_market_pending_wanted_refreshes.rb` (new table, unique player, FK); `db/schema.rb` (regenerated); `pending_wanted_refresh.rb` (model, `mark`); `refresh_wanted_job.rb` (new job); `wanted_refresh.rb` (enqueue instead of refresh); `rebuild_wanted.rb`, `release_player.rb` (clear the mark); `config/initializers/event_store.rb` (comment); `test/test_helper.rb` (clears marks left by tests that commit); tests `refresh_wanted_job_test.rb` (new), `wanted_refresh_test.rb`, `wanted_notices_test.rb`, `market_wanted_cards_test.rb`, `wanted_card_notice_job_test.rb`, `accounts_controller_test.rb`.
- **Review:** none, no lenses launched (the author's choice: one review pass at the end of the epic).
- **Verification:** schema regenerated from the migrations on PG18 (only the new table and its FK in the diff); `bin/rails test test/domains/game test/controllers test/helpers test/jobs test/models test/domains/accounts` 5076 runs, 0 failures, 0 errors; zeitwerk, packwerk, planning-id and file-size checks pass; rubocop clean on every touched Ruby file but the generated `db/schema.rb`. Benchmark and system tests not run (left to the orchestrator).
- **Residual risks:** a mark left by an enqueue failing after commit blocks that player's refreshes until their next `RebuildWanted` (season publish, unban); wanted rows lag a commit by the queue's delay, so a wanted notice for a listing made right after a goal change reads the previous rows; `RefreshWantedJob` and `RebuildWantedJob` have the same body, kept apart as the architecture names them.
