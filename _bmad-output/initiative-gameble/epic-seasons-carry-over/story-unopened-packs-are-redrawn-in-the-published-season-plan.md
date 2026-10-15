---
title: 'Unopened packs are redrawn in the published season'
type: 'feature'
ticket: '6'
created: '2026-10-15'
status: done
baseline_revision: '3c25b58a9514612eddf1b7b9163f3f93929f9be7'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** After a publication, a player's unopened packs still hold the earlier season's cards until each is opened; the bank, the reward and bonus packs keep a stale season (AD-7, R7).

**Approach:** When a season is published, `Game::HealBanksJob` also redraws, for every player, each unopened pack (any kind) of an earlier season in the published one, inside `Game::HealBank`'s transaction under the bank lock. Each card is redrawn within its old card's rarity tier, which keeps the pack's kind, size, odds and guarantees (first-session, reward "Épique or better"), since nothing records which guarantee a pack had. The pack keeps its id, token, kind and availability time.

## Boundaries & Constraints

**Always:** One player per transaction under `Game::BankLock`; lock order unchanged (bank lock first). The redraw updates rows in place (pack ids are referenced by `game_daily_bonus_claims` and `game_goal_rewards`; tokens are in URLs). One shared in-tier redraw used both by the job's path and by `Game::OpenPack#drawn_in_published_season`, which stays as the fallback for an opening that races the job. Idempotent: a pack already in the published season, or opened, is never touched; a second run changes nothing and publishes nothing. An operation that changes state publishes one event. English, no planning ids, no new explanatory comments (correct the existing header comments the change makes false).

**Never:** No migration, no new column, no new event type. No change to the odds tables, to `FirstSessionGuarantee`, `RewardDraw`, `TopUpBank.call` or to how a full bank of the published season is skipped. No redraw of opened packs. No per-player query growth for players with nothing to heal or redraw.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Full stale bank | ten unopened regular packs and one unopened reward pack of season N; season N+1 published, job runs | the same 11 rows (id, token, kind, `available_at`, card count) with `season_id` N+1 and only N+1 cards, each card in its old card's tier, so the reward pack still holds an Épique or better | — |
| Bonus pack | an unopened bonus pack of season N | redrawn as above, 3 cards | — |
| Opened pack | an opened pack of season N | untouched (season, cards, `opened_at`) | — |
| Short stale bank | a bank of season N short of ten | missing packs drawn in N+1 as today, the stale ones redrawn, one transaction, one `Game::BankToppedUp` | — |
| Already current | every unopened pack in the published season, bank full | no operation, no query beyond today's per batch, no event | — |
| Second run | job run again after a redraw | nothing changes, nothing published | — |
| No published season | job runs with no season published | nothing redrawn | — |
| Player deleted meanwhile | `:player_required` | skipped unreported, as today | unchanged |
| Opening races the job | a stale pack opened before the job reaches the player | `OpenPack` still redraws it at opening (the shared redraw) | — |

</intent-contract>

## Code Map

- `packs/game/app/jobs/game/heal_banks_job.rb:20-35` -- per batch one grouped query (`BANK_COUNT`) then `next if` the bank is full. Add a second `FILTER` count of unopened packs whose `season_id` differs from the published season (`DrawPool.current&.season_id`, or `Catalog::PublishedSeason`), and skip only a full bank with no stale pack; keep one grouped query per batch. A player with no pack still goes to `FillBank`.
- `packs/game/app/operations/game/heal_bank.rb:23-35` -- under `lock_bank`, `TopUpBank.heal` then publish `BankToppedUp` only when it inserted. Also redraw the stale unopened packs there; publish one `BankToppedUp` when anything was inserted or redrawn, its data gaining `redrawn:` (a count) beside `packs:`. `BankToppedUp` (`packs/game/app/events/game/bank_topped_up.rb`) has no subscriber; existing tests assert its data `{ player_id:, packs: }`, update them.
- `packs/game/app/operations/game/open_pack.rb:85-95` -- `drawn_in_published_season(pack)`: `Catalog::CardSeasonTiers.call(pack.card_season_ids)` then `Draw.in_tiers(tiers, random:, pool:)`. Move this into one shared place (a `Game` model, e.g. a class method on `Draw` or a small `PackRedraw` module taking a pack or its card ids, the pool and the random) and call it from both.
- `packs/game/app/models/game/draw.rb:35` -- `Draw.in_tiers(tiers, random:, pool:)`; `packs/game/app/models/game/draw_pool.rb:27-43` -- `DrawPool.current` (latest published season, `season_id`, `reset!` for tests).
- `packs/catalog/app/queries/catalog/card_season_tiers.rb` -- tiers of card-seasons in one query; a pack's cards are in `game_packs.card_season_ids` (bigint[]), its season in `season_id`.
- `packs/game/app/models/game/pack.rb` -- `unopened` scope, kinds `regular`, `bonus`, `reward`; the cardinality check per kind is kept by keeping the array length.
- `test/packs/game/heal_banks_job_test.rb` -- :41-63 asserts a full bank of season 1 untouched after a publication, now redrawn; :111-128 counts queries and operations for full banks (keep it for banks already in the published season); `recording_operations` helper :90-109.
- `test/support/game_packs.rb` (`create_pack(player, cards:, available_at:, kind:, opened_at:, season:)`, `fixture_tier_ids`, `game_events`), `test/support/catalog_seeds.rb` (`seed_card_seasons(distinct_scores(150))`), publishing: `perform_enqueued_jobs { Catalog::PublishSeason.new.call(number: season.number).value! }` with `Game::DrawPool.reset!`.
- `test/packs/game/open_pack_test.rb` -- the stale-pack redraw at opening; must keep passing.

## Tasks & Acceptance

**Execution:**
- [x] shared in-tier redraw in `packs/game/app/models/game/` and `open_pack.rb` -- one redraw for opening and healing.
- [x] `packs/game/app/operations/game/heal_bank.rb` -- redraw the player's stale unopened packs in place under the bank lock, beside the heal; one event with `packs:` and `redrawn:` -- the publication's redraw.
- [x] `packs/game/app/jobs/game/heal_banks_job.rb` -- reach players whose bank is full but holds a stale unopened pack, with the same per-batch query count -- every player is redrawn.
- [x] `test/packs/game/heal_banks_job_test.rb` (and a `heal_bank` test where it fits) -- every matrix row, the two broken tests updated -- the story's verification.

**Acceptance Criteria:**
- Given a player with ten banked packs and a weekly reward pack from season N, when season N+1 is published and the job runs, then the same packs keep their availability times and hold only season N+1 cards, the reward pack still an Épique or better.
- Given that redraw done, when the job runs again, then no pack changes and no event is published.

## Implementation Notes

- Shared redraw: `Game::PackRedraw.call(packs, pool:, random:)` returns `{ pack => { season_id:, card_season_ids: } }` for the packs not of the pool's season, tiers read in one `Catalog::CardSeasonTiers` query; it writes nothing. `OpenPack#drawn_in_published_season` and `HealBank#redraw_earlier_seasons` (one `update!` per stale pack, under the bank lock, after `TopUpBank.heal`) both call it.
- `HealBank` still returns `Success(packs inserted)`; `BankToppedUp` data is now `{ player_id:, packs:, redrawn: }`, published once when either is positive.
- `HealBanksJob` reads `Catalog::PublishedSeason` once per run (returns early when none) and adds a second `FILTER` count to the per-batch grouped query; a full bank with no unopened pack of another season is skipped. The full-bank query test goes from 2 to 3 queries: the extra one is per run, not per batch.
- Opening racing the job stays covered by `open_pack_test.rb` (publishes without running the job). Player deleted meanwhile stays covered by the existing deletion concurrency tests.

## Plan Change Log

## Review Triage Log

### 2026-10-15 — Review pass
- verdicts: 7 findings — high 0, medium 0, low 6, false 1, maybe-false 0
- findings:
  - `[low]` `[patch]` a new comment above `HealBanksJob#earlier_season_count` paraphrases the code — deleted.
  - `[low]` `[patch]` a new comment above `HealBank#redraw_earlier_seasons` paraphrases the code — deleted.
  - `[low]` `[patch]` a new comment above the test helper `packs_by_tier` paraphrases the code — deleted.
  - `[false]` `[reject]` `Game::PackRedraw`'s module header is a new explanatory comment — every model and operation of `packs/game` carries a header with its usage line (`FirstSessionGuarantee`, `RewardDraw`, `DrawPool`); dropping it would make this one the exception.
  - `[low]` `[patch]` `Handlers::SeasonPublished`'s header leaves out the redraw — the redraw added.
  - `[low]` `[patch]` the `game:top_up_banks` rake `desc` leaves out the redraw — the redraw added.
  - `[low]` `[patch]` the job test's header was left with a short first line — rewrapped.

## Auto Run Result

- **Summary:** at a season's publication, `Game::HealBanksJob` reaches every player whose bank is short or holds an unopened pack of an earlier season; `Game::HealBank`, under the bank lock, heals the bank as before and redraws each such pack (any kind) in place in the published season, each card within its old card's tier (`Game::PackRedraw`, shared with `Game::OpenPack`'s redraw at opening), keeping id, token, kind, availability time and guarantees; one `Game::BankToppedUp` with `packs:` and `redrawn:`.
- **Files:** `packs/game/app/models/game/pack_redraw.rb` (new), `operations/game/heal_bank.rb`, `operations/game/open_pack.rb`, `jobs/game/heal_banks_job.rb`, `events/game/bank_topped_up.rb`, `handlers/game/handlers/season_published.rb`, `lib/tasks/game.rake`; tests `test/packs/game/heal_banks_job_test.rb` (5 new, 2 updated), `bank_races_test.rb`, `top_up_bank_test.rb` (event data).
- **Review:** quick; 7 findings, 6 low patched (comments and descriptions), 1 rejected as false; none deferred. Follow-up review not recommended.
- **Verification:** `bin/rails test` 2582 runs, 0 failures; `bin/rubocop`, `packwerk check`, `zeitwerk:check` clean.
- **Residual risks:** the job now reads the published season once per run (one more query per run, not per batch); one `UPDATE` per redrawn pack, about a dozen per player once per publication; a card-season without rarity in a stale pack raises in the redraw, as it already did at opening, and that player is reported and skipped.

## Design Notes

Redrawing card by card within the old card's tier is the only way to keep the guarantees: neither the first-session guarantee nor the reward's floor is recorded on the pack, but both are fixed by the tiers the pack holds, and the kind's odds were already applied when it was first drawn. It is the rule `OpenPack` already uses for a stale pack, so the publication and the opening agree.

## Verification

**Commands:**
- `bin/rails test test/packs/game` -- expected: all pass
- `bin/rails test` -- expected: all pass (system tests are skipped)
- `bin/rubocop` -- expected: no offense
- `bundle exec packwerk check` and `bin/rails zeitwerk:check` -- expected: no violation
