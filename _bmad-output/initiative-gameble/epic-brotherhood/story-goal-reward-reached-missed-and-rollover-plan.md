---
title: 'Goal reward: reached, missed and rollover'
type: 'feature'
ticket: '5'
created: '2026-10-07'
status: done
baseline_revision: 'e419296bcc721682f3ba0eafef14b228311cacf9'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: [quick]
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** The weekly goal (story 6.3) only counts: reaching the target grants nothing, and the hub panel shows neither a reached goal nor how last week ended once a new week starts.

**Approach:** When the periodic sum sees a week's total at or above its target, it enqueues a job that runs one per-player operation per contributor of that week: under the player's bank lock it inserts one reward pack (kind `reward`, 5 cards, at least one Épique or better, available now, outside the bank's cap and whatever the reserve holds) and one reward row unique per player and week (AD-9), and publishes `Game::GoalRewardGranted`. The hub panel gains the reached state and last week's result line; a contributor whose reward pack is still unopened gets the reward toast, shown once per browser.

## Boundaries & Constraints

**Always:** One reward per player and week, guaranteed by a unique index (player_id, week_start) and checked under `Game::BankLock`. A reward is never refused for a full reserve or bank (outside the cap of ten). Contributors = players with a contribution row for the week. Banned players get nothing (`Game::Operation#require_player`). No season published: no row, so a later run grants it. The job serves each player in their own transaction; a failure for one player is reported and the others are still served. Jobs are enqueued outside any transaction (AD-13). GET never writes (AD-11): the toast's once-only memory is client-side. French "vous", no title for the player; the Brotherhood line stays the only Brotherhood copy.

**Never:** No broadcast of the gauge (story 6.4), no trade contributions (6.9), no card back with the reward (epic 9), no achievement. No change to the reserve query (AD-7: every unopened available pack counts) or to the bank cap. No separate canister look for the reward pack (EXPERIENCE: not told apart).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Reached | contributors, total reaches target, sum job runs then grant job | each contributor has 1 reward pack (5 cards, at least 1 of tier 4 or 5) and 1 reward row; event published per player | none |
| Once | grant job runs twice / operation called twice | still one pack and one row per player | second call Failure(:already_granted), nothing written |
| Late contributor | a new player contributes after the goal was reached, sum runs | the new total triggers the grant job; the newcomer gets their reward, others nothing more | none |
| Full reserve | contributor holds 10 available packs | the reward is inserted, reserve reads 11 | none |
| Not reached | total < target | nothing granted | Failure(:goal_not_reached) |
| Non-contributor / banned | no row for the week / banned player | nothing granted | Failure(:not_contributor) / Failure(:player_required) |
| No season | no published season | nothing granted, no row | Failure(:no_season) |
| Opens like any pack | reward pack is the oldest available | OpenPack opens it, credits its 5 cards, no bank top-up | none |
| Panel reached | current week total at or above target | "Objectif atteint" status, 24 lit segments | none |
| Panel rollover/missed | previous week 180/200, new week | gauge for the new week and new target; line "Semaine dernière : 180 / 200 · objectif manqué" | none |

</intent-contract>

## Code Map

- `packs/game/app/models/game/pack.rb` -- `kind: reward` exists; `Pack.row(...)` builds a row; reward packs are already outside `Pack.bank`. Unchanged.
- `packs/game/app/operations/game/collect_daily_bonus.rb` -- template for the new operation (BankLock, `DrawPool.current`, `Pack.create!(Pack.row(...))`, claim row, `publish(..., stream_name:)`).
- `packs/game/app/models/game/draw.rb`, `draw_odds.rb`, `first_session_guarantee.rb` -- draw helpers; add `DrawOdds::REWARD` and `DrawOdds::EPIC_OR_BETTER` (assumed odds, Design Notes).
- `packs/game/app/models/game/weekly_goal.rb` -- add `reached?` and a `reached` scope (`total >= target`).
- `packs/game/app/jobs/game/sum_weekly_goal_job.rb` -- `sum` learns whether the row changed; when changed and reached, enqueue `GrantGoalRewardsJob.perform_later(week_start:)`.
- `packs/game/app/jobs/game/heal_banks_job.rb` -- per-player loop with `Rails.error.report` to copy.
- `packs/game/app/queries/game/current_goal.rb` -- one query for the current and previous week: `{ total:, target:, reached:, previous: { total:, target:, reached: } | nil }`.
- `config/initializers/event_store.rb` -- no subscriber for the new event (published for epic 9).
- `app/views/pages/_goal.html.erb`, `app/helpers/goal_helper.rb`, `app/frontend/styles/hub.css` -- panel states.
- `app/controllers/pages_controller.rb`, `app/views/pages/home.html.erb` -- reward toast for the player (`content_for :toasts`).
- `app/views/shell/_toasts.html.erb`, `app/components/toast_component.{rb,html.erb}`, `app/frontend/controllers/toast_controller.ts`, `app/frontend/lib/toast.ts` -- `once:` key: `data-toast-once`; a toast whose key this browser already showed is dropped (localStorage, wrapped in try/catch).
- `test/controllers/pages_controller_test.rb` -- `PLAYER_HUB_QUERIES` gains 1 (reward toast query).

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/20261007165000_create_game_goal_rewards.rb`, `db/schema.rb` -- table `game_goal_rewards` (player_id FK, week_start date, pack_id FK, timestamps; unique player+week; index week_start) -- AD-9 reward row.
- [x] `packs/game/app/models/game/goal_reward.rb`, `packs/game/app/events/game/goal_reward_granted.rb` -- model and event (`{ player_id:, pack_id:, week_start: "YYYY-MM-DD" }`).
- [x] `packs/game/app/models/game/draw_odds.rb`, `packs/game/app/models/game/reward_draw.rb` -- 5 cards at REWARD odds, one replaced at a random position from EPIC_OR_BETTER when none is tier 4 or 5.
- [x] `packs/game/app/operations/game/grant_goal_reward.rb` -- `call(player:, week_start:)` with the failures of the matrix.
- [x] `packs/game/app/jobs/game/grant_goal_rewards_job.rb`, `sum_weekly_goal_job.rb`, `weekly_goal.rb` -- job over ungranted contributors in batches; trigger from the sum.
- [x] `packs/game/app/queries/game/current_goal.rb`, `packs/game/app/queries/game/waiting_goal_reward.rb` -- panel data; the week of the player's newest unopened reward pack.
- [ ] views, helper, CSS, toast `once`, `config/locales/{fr,en}.yml` -- reached status, previous-week line, toast "Objectif atteint" / "Un booster rare rejoint votre réserve.".
- [ ] tests: `test/packs/game/goal_reward_test.rb` (matrix rows), `weekly_goal_test.rb` (CurrentGoal shape), `pages_controller_test.rb` (panel states, toast, budget), `app/frontend/lib/toast.test.ts` (once), `test/system/hub_test.rb` (toast shown once).

**Acceptance Criteria:**
- Given a week whose total reaches its target, when the sum job and the grant job run, then every contributor holds exactly one more unopened reward pack and the hub of each shows the "Objectif atteint" toast once.
- Given the hub on a reached week, then the panel reads "Objectif atteint" with a full gauge, for players and visitors alike, in fr and en.
- Given a new week after a missed one, then the panel shows the new target with an empty gauge and last week's final count marked missed.

## Implementation Notes

Subagents unavailable, done in-session (implementation and the quick review lens). Decisions and surprises:
- No `reached_at` column: reached is derived (`total >= target`; the target is frozen at creation and the total only grows), exposed as `WeeklyGoal.reached`.
- Trigger: `SumWeeklyGoalJob#sum` enqueues `GrantGoalRewardsJob` only when a reached goal's total moved (the update count), so late contributors are rewarded on the next sum and an idle week costs nothing.
- The job skips banned players in its query and reports (does not re-raise) a player's exception, like `HealBanksJob`; Failure results are skipped.
- Toast: rendered by the hub through a new `content_for :toasts` slot of the shell's toast region; `ToastComponent` gained `once:` (`data-toast-once`), and the toast controller drops a toast whose key this browser already showed (`firstShowing` in `app/frontend/lib/toast.ts`, localStorage in try/catch). The hub GET writes nothing.
- The previous-week line uses two literal `t()` calls so `i18n-tasks unused` sees both keys.
- Assertions on the toast region in controller tests use `#toasts > .toast` (the region's `<template>` holds a `.toast` too).
- Hub query budget for a player: 14 -> 15 (`Game::WaitingGoalReward`).
- Files: migration `db/migrate/20261007165000_create_game_goal_rewards.rb` and `db/schema.rb`; Game pack: `goal_reward.rb`, `reward_draw.rb`, `draw_odds.rb`, `weekly_goal.rb`, `grant_goal_reward.rb`, `grant_goal_rewards_job.rb`, `sum_weekly_goal_job.rb`, `current_goal.rb`, `waiting_goal_reward.rb`, `goal_reward_granted.rb`; web: `pages_controller.rb`, `home.html.erb`, `_goal.html.erb`, `shell/_toasts.html.erb`, `toast_component.{rb,html.erb}`, `toast_controller.ts`, `lib/toast.ts`, `hub.css`, `config/locales/{fr,en}.yml`; tests: `goal_reward_test.rb` (new), `weekly_goal_test.rb`, `pages_controller_test.rb`, `hub_test.rb`, `toast.test.ts`.

## Plan Change Log

## Review Triage Log

### 2026-10-07 — Review pass
- verdicts: 3 findings — high 0, medium 0, low 2, false 1, maybe-false 0
- findings:
  - `[low]` `[reject]` `GrantGoalReward` says a run after `Failure(:no_season)` grants the reward later, but for a week that has ended no later sum moves its total, so nothing re-enqueues the job — unreachable in practice: no code unpublishes a season (no `published_at: nil` path in app or packs) and contributions need a published season; a retry schedule would add complexity for a state the game never reaches.
  - `[low]` `[reject]` `GrantGoalRewardsJob` can be enqueued every 10 seconds while a reached week keeps moving, each run re-reading the week's contributions without a reward — one indexed anti-join per run, no write when everyone is served; batching the trigger would add state for no measured cost.
  - `[false]` `[reject]` The reward toast could repeat on every morph refresh of the hub — refuted: the controller checks the once key in `track`, which every path (connect, morph-kept clone, new target) goes through; the system test `hub_test.rb` "goal reward toast shows on the hub once" passes.

## Design Notes

"A zone of its own" is read as: the reward is a pack of its own kind outside the bank (the cap of ten regular packs), granted whatever the reserve holds, so it is never lost; it joins the reserve count and opens in order like any pack (AD-7; EXPERIENCE, "Special booster in the reserve": not told apart among the canisters). The reward pack odds are an open question: assumption REWARD = the bonus odds (no common), EPIC_OR_BETTER = 4 => 8_333, 5 => 1_667 (the bonus odds' 5:1 ratio).

## Verification

**Commands:**
- `bin/rails test` (PARALLEL_WORKERS=2, lane test DB) -- expected: green
- `bin/rubocop` on changed Ruby files, `bundle exec packwerk check`, `bundle exec i18n-tasks missing` -- expected: clean
- `npm run typecheck`, `npx vitest run` -- expected: green
- `bin/rails test test/system/hub_test.rb` (PARALLEL_WORKERS=1) -- expected: green

## Auto Run Result

- Summary: a reached weekly goal now rewards every contributor of its week, once, with a reward pack (5 cards, at least one Épique or better, kind `reward`, available now, outside the cap of ten and never refused for a full reserve) through `Game::GrantGoalReward`, run per player by `Game::GrantGoalRewardsJob`, which the periodic sum enqueues when a reached goal's total moves; `Game::GoalRewardGranted` is published. The hub panel shows "Objectif atteint" with a full gauge, and after the rollover the new week's empty gauge and target with last week's final count (reached or missed). A contributor whose reward pack waits unopened gets the "Objectif atteint" toast once per browser.
- Files changed: see Implementation Notes (migration + schema, 10 Game files, 10 web files, 5 test files).
- Review findings: 0 patches, 0 deferred; rejected: no-season retry for an ended week (unreachable), grant job re-enqueued while a reached week moves (negligible cost), toast repeating on morph (false, tested).
- Follow-up review recommended: false (no patched entries).
- Verification: `bin/rails test` (PARALLEL_WORKERS=2): 1442 runs, 0 failures; system `hub_test.rb`, `shell_test.rb`, `daily_bonus_test.rb` (PARALLEL_WORKERS=1): 35 runs, 0 failures; `bin/rubocop` on changed Ruby files: no offenses; `packwerk validate` + `check`: clean; `i18n-tasks missing` and `unused`: clean; `brakeman`: no warnings; `npm run typecheck`: clean; `npx vitest run`: 135 passed.
- Residual risks: the reward odds (REWARD = bonus odds, EPIC_OR_BETTER 8 333 / 1 667) are an assumption to confirm (spec open question; not yet in pending-approvals.md); `PLAYER_HUB_QUERIES` moved to 15, which other lanes touching the hub may also move; migration 20261007165000 changes `db/schema.rb`.
