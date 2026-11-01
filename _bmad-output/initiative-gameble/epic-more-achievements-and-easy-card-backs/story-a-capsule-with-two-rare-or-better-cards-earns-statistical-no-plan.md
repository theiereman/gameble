---
title: 'A capsule with two Rare-or-better cards earns Statistical Non-Compliance, in play and from history'
type: 'feature'
ticket: '1'
created: '2026-11-01'
status: 'built'
baseline_revision: 'ded021fb11ba64766b8b94ed5924bd3ab41808de'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/AGENTS.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Game::FeedTest "across sets the highest result stands" failed once in a parallel run and may be flaky.
    evidence: |-
      One parallel run of test/domains/game during the review of this build got complete/1 instead of expert/3; it passed alone three times and serially once. The test does not touch achievements. Settled by reproducing it on develop under a seeded parallel run.
    location: >-
      test/domains/game/feed_test.rb:384
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** The achievement catalogue holds only ten counters, and `Game::AchievementProgress` computes every metric for every grant, even of achievements already earned; the epic's thirteen new achievements need a first one-capsule metric and a progress query that later entries extend.

**Approach:** Turn `Game::AchievementProgress` into one SQL statement composed from a map of metric to scalar subquery, computing only the metrics asked for: the grant job and the achievements board ask for the metrics of achievements the player has not unlocked, `Game::GrantAchievement` re-reads under the bank lock only its achievement's metric. Add the metric counting opened `regular` packs whose `card_season_ids` hold at least two cards of rarity Rare or better, and the achievement `statistical_non_compliance` (threshold 1) with its names, conditions and an existing glyph.

## Boundaries & Constraints

**Always:** keys of the ten existing achievements, their order and their grants stay; the new achievement is appended last in `CATALOGUE`; copies count (a pack holding the same Rare card-season twice qualifies); only kind `regular` counts (not `bonus`, not `reward`); unopened packs and other players' packs never count; the backfill (`Game::BackfillAchievementsJob`, rake `game:backfill_achievements`) grants it with `retroactive: true` (no toast) and a live opening grants it once with a toast, both through the unchanged event/handler path; English name "Statistical Non-Compliance", condition "Two cards of Rare or better in one standard capsule"; French draft name "Non-conformité statistique", condition "Deux cartes Rare ou mieux dans une capsule standard"; glyph `gem` (existing `achievement-gem` icons).

**Never:** no migration, no new pixel art, no stored counter or event-derived condition, no change to `ProfileActivity`'s use of `PACKS_OPENED_SQL` / `TRADES_ACCEPTED_SQL`, no planning ids in code or tests, no flavor text key.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Two Rare+ in a regular pack | opened regular pack: rare, epic, 3 commons | metric 1; achievement granted once | No error expected |
| Same Rare twice | opened regular pack: rare, rare, 3 commons | metric 1 | No error expected |
| Near miss | opened regular pack: one legendary, 4 commons/uncommons | metric 0; `GrantAchievement` returns `Failure(:not_reached)` | writes nothing |
| Wrong kind / unopened / other player | bonus or reward pack with two Rare+, unopened regular pack, another player's pack | metric 0 | No error expected |
| Already unlocked | player holds the unlock | grant job asks no metric for it; second grant `Failure(:already_unlocked)` | no row, no event |
| Everything earned | every achievement unlocked | progress query runs no SQL (empty metrics); board tiles earned with progress = threshold | No error expected |
| Visitor | `nil` player | every requested metric 0 | No error expected |

</intent-contract>

## Code Map

- `app/domains/game/app/queries/game/achievement_progress.rb` -- today one fixed `SQL` with six subqueries and `METRICS`; becomes a frozen map metric => subquery SQL (keep `PACKS_OPENED_SQL`, `TRADES_ACCEPTED_SQL` constants: `profile_activity.rb` interpolates them) and `call(player, metrics)` building `SELECT (sq1), (sq2)…` for only those metrics. `METRICS` stays (the map's keys) for the catalogue test. Rarity threshold from `Catalog::Rarity::TIERS.key(:rare)` (TIERS: 1 common … 3 rare … 5 legendary), as `OBTAINED_SQL` already does with `format`.
- `app/domains/game/app/models/game/achievements.rb` -- `Achievement` Data + `CATALOGUE`, `BY_KEY`, `find`, `met`; add the entry and a way to list the catalogue entries not in an unlocked key set (keys are symbols from `UnlockedAchievements`).
- `app/domains/game/app/jobs/game/grant_achievements_job.rb` -- `grant` already reads `UnlockedAchievements`; compute progress only for unearned achievements' metrics.
- `app/domains/game/app/operations/game/grant_achievement.rb` -- `reached` re-reads only `[achievement.metric]` under `lock_bank`.
- `app/domains/game/app/queries/game/achievement_board.rb` -- progress only for unearned metrics; an earned tile's progress is its threshold (as `EarnedAchievements#earned_tile` does).
- `app/helpers/achievements_helper.rb` -- `GLYPHS` (fetch raises on a missing key): add `statistical_non_compliance: "gem"`.
- `config/locales/en.yml` (alphabetical keys under `achievements.names` / `.conditions`) and `config/locales/fr.yml` (catalogue order) -- add both keys.
- `test/support/game_packs.rb` -- `create_pack` defaults to five `portal_one` (an Épique), so every default opened regular pack now meets the new achievement; `fixture_tier_ids` gives common..legendary ids.
- Tests that assert exact unlock lists or "/ 10" totals and will need care: `test/domains/game/achievements_test.rb` (incl. `BackfillAchievementsJobTest#expected`), `achievement_board_test.rb`, `earned_achievements_test.rb`, `grant_milestone_backs_test.rb`, `season_allocation_test.rb`, `unlock_card_back_test.rb`, `grant_achievement_concurrency_test.rb`, `test/controllers/achievements_controller_test.rb`, `pages_controller_test.rb`, `public_profiles_controller_test.rb`, `season_allocations_controller_test.rb`, `accounts_controller_test.rb`, `settings_controller_test.rb`, `test/jobs/player_stream_job_test.rb`, `test/models/player_stream_test.rb`, export tests. Where a test's intent is not this achievement, prefer packs of commons over widening expected lists; totals 10 become 11.

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/queries/game/achievement_progress.rb` -- metric map + `call(player, metrics)` composing one statement from the requested metrics; empty metrics returns `{}` without a query; nil player returns zeros; add the two-Rare-or-better metric -- one statement extended by later metrics
- [x] `app/domains/game/app/models/game/achievements.rb` -- append `statistical_non_compliance` on the new metric, threshold 1; add the unearned-catalogue helper -- single place for "not unlocked"
- [x] `app/domains/game/app/jobs/game/grant_achievements_job.rb`, `app/domains/game/app/operations/game/grant_achievement.rb`, `app/domains/game/app/queries/game/achievement_board.rb` -- use the narrowed progress as in Code Map
- [x] `app/helpers/achievements_helper.rb`, `config/locales/en.yml`, `config/locales/fr.yml` -- glyph and copy
- [x] `test/domains/game/achievements_test.rb` -- catalogue test (eleven entries); metric tests for every matrix row; operation test (granted, near miss `:not_reached`); job test: a live opening of a qualifying capsule via `open_with_jobs` grants it once and broadcasts a toast naming it in `fr` and `en` streams; backfill grants it retroactively with no `PlayerStreamJob`; progress asks only requested metrics (an earned achievement's metric absent from the grant job's read)
- [x] remaining tests listed in Code Map -- update to the eleven-achievement catalogue and the new default-pack grant
- [x] `test/system/achievements_test.rb` (new) -- a player whose recorded opened regular pack holds two Rare-or-better cards, after `Game::BackfillAchievementsJob.perform_now`, signs in and sees "Statistical Non-Compliance" with its condition in the earned group of `/en/achievements`, and "Non-conformité statistique" on `/fr/achievements`; follow existing system tests' sign-in pattern

**Acceptance Criteria:**
- Given a player whose recorded opened regular pack holds two Rare-or-better cards, when `bin/rails game:backfill_achievements` runs twice, then the player holds `statistical_non_compliance` once and its `AchievementUnlocked` event carries `retroactive: true` and no toast job was enqueued.
- Given a player without it, when they open a regular capsule holding a Rare and an Épique, then the achievement is unlocked once and a toast naming it reaches their stream; a second such opening adds nothing.
- Given a signed-in player who earned it, when they visit the achievements screen in English then French, then the tile shows the name and condition in that language with the `gem` glyph, and the count reads out of 11.

## Implementation Notes

- `Achievements.met` is replaced by `Achievements.unearned(unlocked_keys)` and `Achievements.metrics(achievements)` (unique metrics); the grant job and the board both use them, `GrantAchievement` reads `[achievement.metric]`.
- `AchievementBoard.earned_tile` is now public and `EarnedAchievements` reuses it instead of its own copy.
- `AchievementProgress.call` de-duplicates the requested metrics; the repost subquery became `REPOSTS_SQL`.
- Tests: in `achievements_test.rb` the `opened_packs` helper now defaults to commons, and the backfill setup's default packs are commons; the backfill expectation gains `statistical_non_compliance` for the player whose recorded pack holds five Légendaires (four retroactive events). Controller totals moved from 10 to 11; the achievements screen test's to-earn list gains the new tile (its 64 default packs qualify, but a GET grants nothing). A controller test checks the earned tile's name, condition and `gem` glyph in both locales; the board test checks that only unearned metrics are read and that nothing is queried once all are earned.
- `i18n-tasks health` reports a normalization need and one inconsistent interpolation (`back_office.seasons.index.confirm.one`), both pre-existing; CI runs only `i18n-tasks missing`, which is clean.

## Plan Change Log

## Review Triage Log

### 2026-11-01 — Review pass
- verdicts: 2 findings — high 0, medium 0, low 0, false 1, maybe-false 1
- findings:
  - `[false]` `[reject]` 17 "connection refused" errors on port 5433 in a parallel run of the domain/controller tests — the Postgres instance shared by six parallel builds refused connections for a while; the same files and the full suite (3822 runs) pass on rerun, so the change does not cause it.
  - `[maybe-false]` `[defer]` `test/domains/game/feed_test.rb:384` ("across sets the highest result stands…") failed once in a parallel run (expected expert/3, got complete/1) and passed four times after — a test this diff does not touch; settled by reproducing it under a seeded parallel run on develop.

## Design Notes

The ticket's open question (one statement or one query per metric family) is settled as one statement: each metric is a scalar subquery, so streak metrics (window functions) and holdings metrics of later entries add entries to the map; a metric later needing Ruby (studio normalisation) can be computed beside the statement for the same `metrics` argument.

```ruby
METRIC_SQL = { packs_opened: PACKS_OPENED_SQL, ..., two_rare_or_better_capsules: TWO_RARE_OR_BETTER_SQL }.freeze
def self.call(player, metrics)
  return metrics.index_with(0) if player.nil?
  return {} if metrics.empty?
  sql = "SELECT #{metrics.map { "(#{METRIC_SQL.fetch(it)})" }.join(", ")}"
  ...
end
```

The metric subquery counts copies by unnesting the array and joining `catalog_card_seasons` on each element, filtering `rarity >= rare`, `>= 2`, over `game_packs` with `kind = 'regular'`, `opened_at IS NOT NULL`, `player_id = :player_id`.

## Verification

**Commands:** (with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_w30_1 CHROME_BIN=/usr/bin/chromium`)
- `bin/rails test test/domains/game test/controllers test/jobs test/models test/helpers` -- expected: all pass
- `bin/rails test` -- expected: all pass
- `bin/rails test test/system/achievements_test.rb` -- expected: pass
- `bundle exec i18n-tasks health` (or the repo's i18n check in `bin/ci`), `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/rubocop` on touched files, `script/check_planning_references`, `script/check_file_sizes` -- expected: clean

## Auto Run Result

Status: built

**Summary:** `Game::AchievementProgress` is now one SQL statement composed from a metric => scalar-subquery map, computing only the metrics it is asked for: the grant job and the achievements board ask for the metrics of achievements not yet unlocked, and `Game::GrantAchievement` re-reads under the bank lock only its achievement's metric. The new metric `two_rare_or_better_capsules` counts opened regular packs holding at least two Rare-or-better cards (copies count), and `statistical_non_compliance` (threshold 1, glyph `gem`) is the eleventh achievement, with its English name and condition from achievements.md and a French draft ("Non-conformité statistique", "Deux cartes Rare ou mieux dans une capsule standard"), both to be replaced by entry 5. The ticket's open question is settled: one statement, extended by later metrics as map entries.

**Files changed:**
- `app/domains/game/app/queries/game/achievement_progress.rb` -- metric map, `call(player, metrics)`, the new metric
- `app/domains/game/app/models/game/achievements.rb` -- new catalogue entry; `unearned` and `metrics` replace `met`
- `app/domains/game/app/jobs/game/grant_achievements_job.rb` -- reads only unearned metrics
- `app/domains/game/app/operations/game/grant_achievement.rb` -- re-reads only its metric
- `app/domains/game/app/queries/game/achievement_board.rb` -- reads only unearned metrics; earned tile progress = threshold; `earned_tile` public
- `app/domains/game/app/queries/game/earned_achievements.rb` -- reuses `AchievementBoard.earned_tile`
- `app/helpers/achievements_helper.rb` -- `gem` glyph for the new key
- `config/locales/en.yml`, `config/locales/fr.yml` -- name and condition
- `test/domains/game/achievements_test.rb`, `achievement_board_test.rb`, `earned_achievements_test.rb`, `grant_milestone_backs_test.rb`, `test/controllers/achievements_controller_test.rb`, `pages_controller_test.rb`, `public_profiles_controller_test.rb` -- new metric, operation, job, backfill and screen tests; totals 10 -> 11
- `test/system/achievements_test.rb` -- new: the backfilled achievement on the screen in English and French

**Review findings:** quick lens, 2 findings. Patches applied: none. Deferred: 1 (possible flake in `test/domains/game/feed_test.rb:384`, unverified, not touched by this change). Rejected: 1 (Postgres connection refusals in one parallel run: shared-environment load, reruns clean). Follow-up review recommended: false (0 patched: high 0, medium 0, low 0).

**Verification:** `bin/rails test` 3822 runs, 0 failures (twice: implementer and parent); `bin/rails test test/system/achievements_test.rb` 1 run, 0 failures; `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bin/rubocop` on touched files, `script/check_planning_references`, `script/check_file_sizes`, `bundle exec i18n-tasks missing` clean. No frontend file changed, so vitest and format checks do not apply.

**Residual risks:** the staging checks of the ticket's verify (backfill on real history, live toast, both languages) remain for the author, with entry 4. The new metric's subquery unnests every opened regular pack of the player on each grant job until the achievement is earned; cheap per player, but the backfill runs it for every player. The French copy is a builder draft.
