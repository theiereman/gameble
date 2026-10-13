---
title: 'Achievements engine'
type: 'feature'
ticket: '10'
created: '2026-10-12'
status: 'built'
baseline_revision: '224cc3934833c61bacd0d4b7a95d6a1a2d065e08'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 1
followup_review_recommended: false
context: ['{project-root}/AGENTS.md']
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** Players earn nothing for their milestones: no achievement exists, no unlock is recorded, and the card backs epic has no achievement event to unlock on.

**Approach:** A catalogue of ten achievements as a constant in `Game`, each a progress metric and a threshold. A handler subscribed to the events that move a metric enqueues a per-player job; the job reads the player's progress once and runs `Game::GrantAchievement` for each achievement now met and not yet unlocked. The operation inserts one unlock row (unique per player and achievement) and publishes `Game::AchievementUnlocked`; `PlayerStream` turns that event into a private toast for the player. A backfill job and rake task grant what players already met when the engine ships, silently.

## Boundaries & Constraints

**Always:** Writes only through the operation; one event per operation transaction; handlers write nothing and publish nothing (they only enqueue; jobs leave after commit through `enqueue_after_transaction_commit`). Uniqueness of an unlock is the database's (unique index, `insert_all … unique_by … returning`): a race or rerun grants nothing twice and never fails. State tables are the truth for every metric (no event replay). Event data carries identifiers and the achievement key only. Banned and deleted players get nothing. Every string in `en.yml` and `fr.yml`. Schema change through a migration, `db/schema.rb` regenerated on Postgres 18 with the run's `DATABASE_URL`. No planning ids, no explanatory comments (AGENTS.md).

**Never:** No SUCCÈS screen, menu 06, PLUS row, progress bars or condition copy (the next story). No card back unlocks. No change to `Game::OpenPack`, `Game::AcceptTrade` or `Game::RepostCard` (they already publish what the handler needs). No new `gameble:*` signal. No reads added inside the opening's transaction.

**Decisions (author away):**
- D1 catalogue, in this order, key → metric ≥ threshold: `first_booster` packs_opened 1; `first_epic` epics_obtained 1; `first_legendary` legendaries_obtained 1; `first_complete_set` sets_completed 1; `first_trade` trades_accepted 1; `boosters_10` packs_opened 10; `boosters_100` packs_opened 100; `boosters_500` packs_opened 500; `three_complete_sets` sets_completed 3; `first_repost` reposts 1.
- D2 metrics from state: packs_opened = player's packs with `opened_at` set (any kind); epics/legendaries_obtained = player's holding rows (any quantity: a holding row is kept at 0 when traded away, so "ever obtained", by pull or trade) whose card-season rarity is exactly 4 / exactly 5; sets_completed = player's `game_set_completions`; trades_accepted = `game_trades` with status `accepted` where the player is proposer or recipient; reposts = player's `game_feed_entries` of kind `repost`.
- D3 triggers: `Game::PackOpened`, `Game::SetCompleted`, `Game::CardReposted` (the player), `Game::TradeAccepted` (proposer and recipient).
- D4 toast: title "Succès débloqué" / "Achievement unlocked", message the achievement's name. Backfill grants publish the event with `retroactive: true` and show no toast.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| First opening | player opens their first pack | `first_booster` row + one AchievementUnlocked; toast in the player's stream only | — |
| Épique pulled | opening credits an Épique (rarity 4) | `first_epic` granted; a Légendaire alone grants `first_legendary` only | — |
| Tenth opening | 10th pack opened | `boosters_10` granted once; 11th opening grants nothing more | — |
| Set completed | SetCompleted for the 1st / 3rd set | `first_complete_set` / `three_complete_sets` | — |
| Trade accepted | trade between two players | `first_trade` for both | — |
| Repost | first repost | `first_repost` | — |
| Already unlocked | operation called again or two jobs race | no second row, no event | `Failure(:already_unlocked)` |
| Not met | operation called below threshold | nothing written | `Failure(:not_reached)` |
| Unknown key | key not in catalogue | nothing written | `Failure(:unknown_achievement)` |
| Banned / deleted / nil player | — | nothing written | `Failure(:player_required)` |
| Backfill | existing player who met conditions before the engine | rows granted, events with `retroactive: true`, no toast; rerun grants nothing | per-player error reported, others served |
| Account deleted | `Game::ReleasePlayer` | the player's unlock rows deleted | — |

</intent-contract>

## Code Map

- `db/migrate/` (latest `20261012100002_*`) -- new `create_game_achievement_unlocks`: `player_id` bigint FK `accounts_players`, `achievement` string not null, `unlocked_at` datetime not null, timestamps; unique index `[player_id, achievement]`. Copy style of `20261007150100_create_game_set_completions.rb`.
- `packs/game/app/models/game/set_completion.rb`, `first_discovery.rb` -- pattern for `insert_all … unique_by … returning`. New `packs/game/app/models/game/achievement_unlock.rb` (table `game_achievement_unlocks`).
- New `packs/game/app/models/game/achievements.rb` -- `Achievement = Data.define(:key, :metric, :threshold)`, `CATALOGUE` (D1, ordered), lookup by key; `met?(progress)`.
- New `packs/game/app/queries/game/achievement_progress.rb` -- `call(player)` → `{ packs_opened:, epics_obtained:, legendaries_obtained:, sets_completed:, trades_accepted:, reposts: }` in one SQL of scalar subqueries (D2; `Game::TierCounts` shows the raw-SQL style with `catalog_card_seasons.rarity`); zeros for nil. The next story reads it for progress bars.
- `packs/game/app/operations/game/operation.rb` (`require_player`, `stream_name`), `grant_goal_reward.rb` -- operation shape. New `packs/game/app/operations/game/grant_achievement.rb`: `call(player:, achievement:, retroactive: false)`; failures of the matrix; publishes `Game::AchievementUnlocked` `{ player_id:, achievement: "<key>" }` plus `retroactive: true` only when retroactive.
- New `packs/game/app/events/game/achievement_unlocked.rb` -- empty class like `card_reposted.rb`.
- New `packs/game/app/handlers/game/handlers/achievements.rb` -- `EVENTS` map event class → player id keys (D3); `call(event)` enqueues `GrantAchievementsJob.perform_later(player_id)` per player. Subscribe in `config/initializers/event_store.rb` next to `PackOpenedFeed` (`to: Game::Handlers::Achievements::EVENTS.keys`, like `PlayerActivity`).
- New `packs/game/app/jobs/game/grant_achievements_job.rb` (`< ActiveJob::Base`, like `grant_goal_rewards_job.rb`) -- `perform(player_id, retroactive: false)`: player via `Accounts::PlayerById`, skip nil/banned/deleted; progress once; unlocked keys once; `GrantAchievement` for each met and missing key in catalogue order.
- New `packs/game/app/jobs/game/backfill_achievements_job.rb` (pattern `backfill_player_states_job.rb`, `Accounts::PlayersInBatches.call`) -- per player the same grant with `retroactive: true`, `Rails.error.report` on error. `packs/game/lib/tasks/game.rake` -- `game:backfill_achievements` task like `backfill_player_states`.
- `packs/game/app/operations/game/release_player.rb` -- delete the player's unlocks with the other derived rows.
- `app/models/player_stream.rb` -- add `Game::AchievementUnlocked` to `EVENTS`; notice `{ player_id:, achievement: }` (no `topic`), none when `retroactive`. `app/jobs/player_stream_job.rb` -- topics from `filter_map`, `achievements:` local; `app/views/player_streams/_update.turbo_stream.erb` -- one `ToastComponent` per achievement appended to `toasts`. Signals stay trades/friends only (`app/frontend/lib/stream_actions.ts` unchanged).
- `config/locales/{en,fr}.yml` -- `achievements.unlocked.title`, `achievements.names.<key>` (ten); `config/i18n-tasks.yml` `ignore_unused` gains `achievements.names.*`.
- Tests: `test/support/game_packs.rb` (`create_pack`, `fixture_tier_ids` → [common, uncommon, rare, epic, legendary], `game_events`); `test/packs/game/repost_card_test.rb`, `goal_reward_test.rb` for style; `test/jobs/player_stream_job_test.rb`, `test/models/player_stream_test.rb` for stream assertions; `test/packs/accounts/delete_player_test.rb`. Existing tests asserting no enqueued jobs after an opening, trade or repost may need the new job allowed.
- Loop 1: `app/components/toast_component.{rb,html.erb}` (`once:` is the model for a new keyword), `app/frontend/controllers/toast_controller.ts` (`track`, `toastTargetConnected`, `add`), `app/frontend/lib/toast.ts` + `toast.test.ts`, `app/frontend/lib/events.ts` (declare the event beside its neighbours), `app/frontend/components/Booster.tsx` (`status` state ~L177, `complete()` ~L628; statuses `sealed`, `waiting`, `arming`, `ejecting`, `inventory`, `legendarySignal`, `complete`), `test/system/booster_test.rb`, `test/components/` for `ToastComponent`.

## Tasks & Acceptance

**Execution:**
- [x] migration + `db/schema.rb` -- unlock table.
- [x] `achievements.rb`, `achievement_unlock.rb`, `achievement_progress.rb`, `achievement_unlocked.rb` -- catalogue, row, metrics, event.
- [x] `grant_achievement.rb` -- the operation.
- [x] `handlers/achievements.rb`, `event_store.rb`, `grant_achievements_job.rb` -- triggers.
- [x] `backfill_achievements_job.rb`, `game.rake` -- backfill.
- [x] `release_player.rb` -- deletion.
- [x] `player_stream.rb`, `player_stream_job.rb`, `_update.turbo_stream.erb`, locales, `i18n-tasks.yml` -- private toast.
- [x] tests: `test/packs/game/achievements_test.rb` (every matrix row, progress metrics each, catalogue has ten keys, end to end: an opening with `perform_enqueued_jobs` grants `first_booster` and publishes once; a race of two `GrantAchievement` calls yields one row), backfill job test, player stream job/model tests (toast fr/en, retroactive silent, no signal), delete player test.

- [x] Follow-up review fixes, loop 1 (2026-10-12, see Plan Change Log; leave every task above as it is):
  - [x] `packs/game/app/operations/game/grant_achievement.rb` -- inside `transaction`, take `step lock_bank(player)` first (as `GrantGoalReward` does), so a grant that waited on an account deletion (`Game::ReleasePlayer` deletes unlocks under the same `BankLock`) writes no row and publishes nothing (`Failure(:player_required)`). Test: a grant running while a deletion holds the lock leaves no unlock and no event (pattern `test/packs/game/delete_player_concurrency_test.rb`, its own teardown).
  - [x] The achievement toast never shows while an opening is being revealed: `app/frontend/lib/events.ts` declares `"gameble:opening-revealing": { revealing: boolean }`; `app/frontend/components/Booster.tsx` dispatches it from its `status` (revealing while `arming`, `ejecting`, `inventory` or `legendarySignal`; not while `sealed`, `waiting` or `complete`) and `{ revealing: false }` on unmount; `ToastComponent` gains `after_reveal:` rendering `data-toast-after-reveal`; `app/frontend/controllers/toast_controller.ts` holds (out of the DOM, untimed) every toast carrying that attribute that arrives while an opening is revealing and adds them, in arrival order, once it is not (and drops them on disconnect); other toasts are unchanged. The achievement toast in `_update.turbo_stream.erb` sets `after_reveal: true`. Tests: vitest for the hold and release (and that an unmarked toast is not held), the component test for the attribute, a system test in `test/system/booster_test.rb` that a marked toast appended during a reveal shows only at "INVENTAIRE COMPLET".
  - [x] `_bmad-output/initiative-gameble/pending-approvals.md` -- add an open item "After the next deploy: `bin/rails game:backfill_achievements` (2026-10-12)": run it right after deploying, since until then a veteran's first opening, trade or repost grants their past milestones live, each with a toast and without `retroactive`. Add only; never settle or edit other entries.

**Acceptance Criteria:**
- Given a signed-in player opening their first pack, when the enqueued jobs run, then one `first_booster` unlock row exists, one `Game::AchievementUnlocked` is on their stream, and their player stream (only theirs) receives the "Succès débloqué · Premier booster" toast.
- Given a player already holding an unlock, when any trigger fires again, then no row and no event are added.
- Given a player opening a pack that unlocks an achievement, when the toast reaches their browser during the reveal, then it shows only once every card of the pack is revealed.
- Given players who met conditions before the engine shipped, when `bin/rails game:backfill_achievements` runs (twice), then each met achievement is granted exactly once, without toast.

## Implementation Notes

- `Game::GrantAchievement` re-reads `Game::AchievementProgress` inside its transaction to answer `:not_reached`, so the job's single progress read only chooses which keys to try; a grant costs one extra scalar-subquery read.
- `Game::GrantAchievementsJob.grant(player, retroactive:)` is shared by the trigger job and the backfill, which walks `Accounts::PlayersInBatches` (good standing only).
- The rake task prints a line and does not abort: grant failures are reported per player to the error tracker, and a rerun picks them up.
- Names (en/fr): First booster / Premier booster, First Epic / Première Épique, First Legendary / Première Légendaire, First complete set / Premier set complet, First trade / Premier échange, 10/100/500 boosters, Three complete sets / Trois sets complets, First repost / Premier repost.
- The race test lives in `test/packs/game/grant_achievement_concurrency_test.rb` (non-transactional, like the other concurrency tests).

## Plan Change Log

- 2026-10-12 — Review pass 1. Triggering findings: (1) `GrantAchievement` takes no bank lock, so a grant racing an account deletion leaves an unlock row and an event for the deleted player; (2) the achievement toast reaches the player within a second or two of the opening's commit, while the booster island is still revealing, so "Première Légendaire" / "Première Épique" / "Premier set complet" name the pack's content before its cards are turned; (3) until `game:backfill_achievements` runs after the deploy, a veteran's first action grants their past milestones live with toasts and without `retroactive`. Amended: the task group "Follow-up review fixes, loop 1", the Code Map's loop-1 line, one acceptance criterion, and the booster system test and typecheck in Verification. Known-bad state avoided: rows left behind by a deletion; a spoiled reveal; an untracked post-deploy step. KEEP: everything the first implementation built, saved as `/tmp/claude-1000/-home-teyermann-projets-gameble/a0dccedd-eab9-4401-b59c-dcfbc3b3c22b/scratchpad/achievements-pass0-keep.patch` (apply it with `/usr/bin/git apply` first, then do the loop-1 tasks): the migration and schema, catalogue, progress query, unlock model, operation, event, handler, grant and backfill jobs, rake task, `ReleasePlayer` deletion, `PlayerStream` notice, stream job and partial, locales and names, i18n-tasks ignore, and every test it added.

## Review Triage Log

### 2026-10-12 — Review pass
- verdicts: 3 findings — high 0, medium 2, low 1, false 0, maybe-false 0
- findings:
  - `[medium]` `[bad_plan]` A grant racing an account deletion leaves an unlock row and an AchievementUnlocked for the deleted player — verified: `GrantAchievement` checks `require_player` on the object it was handed and takes no `BankLock`, while `ReleasePlayer` deletes unlocks under that lock and the soft-deleted player row keeps the FK valid; plan amended (loop-1 task 1).
  - `[medium]` `[bad_plan]` The achievement toast spoils the booster reveal — verified: the opening commits before the island deals and flips, the handler's job then the player stream job broadcast to `#toasts` within seconds, and nothing in the toast region waits for the reveal, which withholds each card until it is flipped (`Booster.tsx`, `TierCounts.before_opening`); plan amended (loop-1 task 2).
  - `[low]` `[bad_plan]` Before the backfill runs, a veteran's first action grants past milestones live, with toasts and no `retroactive` — verified: the trigger job passes `retroactive: false` and nothing tracks running the task after the deploy; folded into the amendment (loop-1 task 3, a pending-approvals item).

### 2026-10-12 — Review pass (loop 1)
- verdicts: 7 findings — high 0, medium 0, low 6, false 1, maybe-false 0
- findings:
  - `[low]` `[reject]` A held achievement toast is lost when the player leaves the booster page mid-reveal (the toast region and the island go with the Turbo visit) — real, but rare: an unlock coincides with an opening only a handful of times per player, and the player has to leave before the last card; the unlock row stays and the next story's screen shows it; carrying held toasts across pages needs storage and a replay path.
  - `[low]` `[patch]` New explanatory comments against AGENTS.md (`toast_component.rb`, `toast_controller.ts` header, `events.ts`, `toast.ts`, `booster.ts`) — deleted.
  - `[false]` `[reject]` The plan's "No new `gameble:*` signal" forbids `gameble:opening-revealing` — refuted: that line is about the player stream's signals (the Code Map: "Signals stay trades/friends only", `stream_actions.ts` unchanged, and it is unchanged); the new name is an island-to-shell DOM event declared in `events.ts`, as AGENTS.md requires.
  - `[low]` `[patch]` `game:backfill_achievements` printed that every player holds what they met even after reported failures — reworded: "done; any failure went to the error tracker, and a rerun grants only what is missing".
  - `[low]` `[reject]` A player banned during the backfill and later unbanned gets their past milestones live, with toasts — real but rare (a ban lifted after the deploy); `GrantAchievement` refuses banned players, so covering it needs a second backfill path.
  - `[low]` `[patch]` `GrantAchievementsJob` read the model directly (`AchievementUnlock.keys_of`) against AGENTS.md's "read through the pack's queries" — moved to `Game::UnlockedAchievements.call(player)`, `keys_of` removed.
  - `[low]` `[patch]` `delete_player_concurrency_test.rb`'s `released` ("Every table Game::ReleasePlayer empties") omitted `Game::AchievementUnlock` — added.

## Verification

All Rails commands with `DATABASE_URL=postgres://postgres:postgres@localhost:5433/gameble_test_auto_6_10` exported (its own test database, shared Postgres); never `docker compose`, never touch `gameble_test` or the development databases. Run git as `/usr/bin/git` (the plain `git` wrapper is refused in this worktree); never commit, push or stash. Never run `pkill` on test processes (other builds share the machine). `PARALLEL_WORKERS=2` for `bin/rails test`.

**Commands:**
- `RAILS_ENV=test bin/rails db:drop db:create db:migrate` then `git diff db/schema.rb` -- expected: only the new table
- `bin/rails test` -- expected: green
- `bin/rails test:system TEST=test/system/booster_test.rb` (PARALLEL_WORKERS=1) -- expected: green
- `npm run test:js`, `npm run typecheck`, `bin/rubocop`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused` -- expected: clean

## Auto Run Result

Status: built.

**Summary.** Ten achievements live in `Game::Achievements::CATALOGUE` (first booster, first Épique, first Légendaire, first complete set, first trade, 10/100/500 boosters, three complete sets, first repost), each a progress metric read from state tables (`Game::AchievementProgress`, one SQL) and a threshold. `Game::Handlers::Achievements` (on PackOpened, SetCompleted, CardReposted, TradeAccepted for both players) enqueues `Game::GrantAchievementsJob`, which runs `Game::GrantAchievement` for each met achievement not yet unlocked: under the player's bank lock it inserts a row of `game_achievement_unlocks` (unique per player and achievement) and publishes `Game::AchievementUnlocked`. `PlayerStream` turns the event into a private "Succès débloqué · <name>" toast; the toast waits until a booster reveal in progress is over (`gameble:opening-revealing`, `data-toast-after-reveal`). `game:backfill_achievements` (`Game::BackfillAchievementsJob`) grants what players met before the engine shipped, silently (`retroactive: true`). Account deletion deletes the unlocks.

**Files.**
- `db/migrate/20261012140000_create_game_achievement_unlocks.rb`, `db/schema.rb` -- the unlock table.
- `packs/game/app/models/game/{achievements,achievement_unlock}.rb`, `queries/game/{achievement_progress,unlocked_achievements}.rb`, `events/game/achievement_unlocked.rb`, `operations/game/grant_achievement.rb`, `handlers/game/handlers/achievements.rb`, `jobs/game/{grant_achievements,backfill_achievements}_job.rb`, `operations/game/release_player.rb`, `lib/tasks/game.rake`, `config/initializers/event_store.rb` -- catalogue, metrics, grant, triggers, backfill, deletion.
- `app/models/player_stream.rb`, `app/jobs/player_stream_job.rb`, `app/views/player_streams/_update.turbo_stream.erb`, `app/components/toast_component.{rb,html.erb}` -- the private toast.
- `app/frontend/lib/{events,toast,booster}.ts`, `app/frontend/controllers/toast_controller.ts`, `app/frontend/components/Booster.tsx` -- the toast held during a reveal.
- `config/locales/{en,fr}.yml`, `config/i18n-tasks.yml` -- title and ten names.
- `_bmad-output/initiative-gameble/pending-approvals.md` -- open item: run `game:backfill_achievements` after the next deploy.
- Tests: `test/packs/game/achievements_test.rb`, `grant_achievement_concurrency_test.rb` (new); `player_stream_test.rb`, `player_stream_job_test.rb`, `delete_player_test.rb`, `delete_player_concurrency_test.rb`, `toast_component_test.rb`, `toast.test.ts`, `booster.test.ts`, `test/system/booster_test.rb`.

**Review.** Pass 1 (quick): 3 findings, all `bad_plan` (medium: grant racing an account deletion; medium: toast spoiling the reveal; low: veterans' live grants before the backfill), plan amended and code re-derived (loop 1). Pass 2 (quick): 4 low patched (comments, rake message, query read, stale test list); rejected: a held toast lost when leaving mid-reveal (rare, needs storage), a player unbanned after the backfill gets live toasts (rare, needs a second path), and one false (the "no new signal" line is about stream signals). Deferred: none. Patched by verdict on the last pass: high 0, medium 0, low 4.

**Follow-up review recommended:** false (no high and fewer than two medium patched on the last pass).

**Verification.** `RAILS_ENV=test bin/rails db:drop db:create db:migrate` reproduces `db/schema.rb` (only the new table). `bin/rails test` (PARALLEL_WORKERS=2): 2225 runs, 2 failures, both outside this change and green under `TZ=UTC`: `sessions_controller_test.rb:316` and `trades_of_test.rb:62` measure 30- and 14-day spans across the 2026-10-25 DST change in the machine's zone. System `booster_test.rb` and `shell_test.rb`: 62 runs green (before the comment-only patch). `npm run test:js` 224 passed, `npm run typecheck`, `bin/rubocop`, `bundle exec packwerk check`, `bin/rails zeitwerk:check`, `i18n-tasks missing` and `unused`: clean.

**Residual risks.**
- `bin/rails game:backfill_achievements` must run right after the deploy (pending-approvals item); until then veterans get past milestones live, with toasts and without `retroactive`.
- A held achievement toast is dropped if the player leaves the booster page before the last card; a player unbanned after the backfill gets past milestones live.
- Every opening, trade, repost and set completion enqueues one grant job (a few indexed reads when nothing is new).
- Achievement names (en/fr) are drafts for the author; the next story adds the screen and condition copy.
- The migration was renumbered to 20261012140000 because the main checkout holds untracked 20261012120000-120003 migrations of another branch; `db/schema.rb`'s version will need the usual merge care.
- The two DST-dependent tests fail on any branch until 2026-10-25 passes or they are fixed.
