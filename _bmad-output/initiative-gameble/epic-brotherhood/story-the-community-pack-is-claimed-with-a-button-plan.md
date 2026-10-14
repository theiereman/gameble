---
title: 'The community pack is claimed with a button'
type: 'feature'
ticket: '17'
created: '2026-10-14'
status: 'built'
baseline_revision: '703461a'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
context: ['{project-root}/AGENTS.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** When the weekly goal is reached, the grant job drops a reward pack straight into each contributor's reserve, above the cap of ten, without the player doing anything. The author wants the reward to wait until the player claims it, and the claim to respect the reserve's cap like the daily booster (triage, 2026-10-12).

**Approach:** The grant job now records each contributor's reward row with no pack: the reward is earned and waiting. A POST from a claim button on the hub's goal panel runs a new per-player operation that, under the bank lock, draws the reward pack (5 cards, at least one Épique or better), links it to the row and publishes its event. It is refused while the reserve holds ten packs, as the daily booster is. The button then shows the reward collected.

**Decisions (author, 2026-10-14):** An unclaimed reward waits forever: the panel offers the oldest waiting reward until it is claimed, so none is lost. The claim sits under the panel's "Récompense" line: a small secondary button « Récupérer » / "Collect", replaced by the state word « Récupéré » / "Collected" in lime once claimed. The goal reward toast ("Objectif atteint / Un booster rare rejoint votre réserve.") is dropped; the button is the signal. The copy is the one proposed in the plan (the author answered the other questions without changing it): full line « Ouvrez un booster pour récupérer votre booster rare. » / "Open a booster to collect your rare booster."; success toast « Votre booster rare rejoint votre réserve. » / "Your rare booster joins your reserve."; refusals `reward_reserve_full` « Votre réserve est pleine : ouvrez un booster pour récupérer votre booster rare. » / "Your reserve is full: open a booster to collect your rare booster.", `reward_already_claimed` « Vous avez déjà récupéré ce booster rare. » / "You have already collected this rare booster.", `reward_not_earned` « Aucun booster rare ne vous attend pour cette semaine. » / "No rare booster waits for you for that week.", `reward_no_season` « Aucune saison de cartes n'est ouverte. Revenez plus tard pour votre booster rare. » / "No card season is open. Come back later for your rare booster."; the « Comment ça marche » reward line says a contributor can collect a reward booster on the hub while their reserve holds fewer than 10 boosters.

## Boundaries & Constraints

**Always:** Earning stays once per player and week (unique row, written by the job's operation). A claim adds at most one pack per reward row: it runs under `Game::BankLock`, and a claimed row (pack set) refuses any second claim. The cap is the daily booster's: `Game::Reserve.full?`, the reserve the packs chip shows. The pack is drawn at claim time from the current season. The claim is a POST behind a Pundit policy and a rate limit. The hub GET writes nothing. The claim area is per player and never part of the public goal broadcast. Every new string goes in `en.yml` and `fr.yml`, using "vous" and no title for the player.

**Never:** No per-player live push of the button. It appears on the next hub render, like the reward toast today. No change to the reward odds, the grant trigger (the periodic sum), the reserve query or the daily booster. No card back. No database id in the claim URL; the week (`YYYY-MM-DD`) names the reward. No new last-activity kind.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Earned | goal reached, grant job runs | each contributor has 1 reward row with no pack; no pack added; `GoalRewardGranted` published | none |
| Claim | waiting reward, reserve < 10 | 1 reward pack (5 cards, ≥1 tier 4 or 5, available now) linked to the row; `GoalRewardClaimed`; the panel shows it collected | none |
| Second claim | row already has its pack (double click, replay) | nothing added | `Failure(:reward_already_claimed)` |
| Reserve full | 10 available unopened packs | nothing added, the row still waits; disabled button with the reason on the panel | `Failure(:reward_reserve_full)`, message in fr and en |
| Not earned | no row for that week (non-contributor, goal not reached) | nothing added | `Failure(:reward_not_earned)` |
| No season | no published season | nothing added, the row still waits | `Failure(:reward_no_season)` |
| Banned / visitor | banned player / signed out | nothing added | `Failure(:player_required)` / Pundit sign-in redirect |
| Rewards granted before this change | row whose pack already exists | reads as collected; no backfill | none |

</frozen-after-approval>

## Code Map

- `packs/game/app/operations/game/grant_goal_reward.rb` -- keep the name and its lock/reached/contributed/ungranted steps. Drop the pack insert, `RewardDraw`, `published_pool` and `:no_season`. Create `GoalReward` with `pack_id: nil` and publish `GoalRewardGranted` without `pack_id`. Return the reward row. Rewrite the header comment (it says outside the cap and still carries planning ids; write the new one without them).
- `packs/game/app/operations/game/collect_daily_bonus.rb` -- the template for the claim: `lock_bank`, `published_pool`, `room_in_reserve` (`Reserve.full?(Reserve.count(player.id, now:))`), `Pack.create!(Pack.row(...))`, `publish(..., stream_name:)`. Use `kind: :reward`, `RewardDraw.cards(pool:, random:)` and `available_at: now`, as `GrantGoalReward` does today (lines 39-41).
- `packs/game/app/models/game/goal_reward.rb` -- add `scope :unclaimed` (`pack_id: nil`) and `claimed?`.
- `packs/game/app/events/game/goal_reward_granted.rb` -- data becomes `{ player_id:, week_start: }`. It has no subscriber (`config/initializers/event_store.rb`), so the change is safe.
- `packs/game/app/queries/game/waiting_goal_reward.rb` -- today it returns the newest reward whose pack is unopened (only the toast reads it). Replace it with one query the panel's claim slot reads: `{ week_start:, claimed: }` or nil, as one indexed read: the oldest unclaimed reward, else the newest claimed reward of the current or previous week (the collected state), else nil. Keep `PLAYER_HUB_QUERIES` (`test/controllers/pages_controller_test.rb:14`, 19) unchanged.
- `app/controllers/daily_bonuses_controller.rb`, `app/views/daily_bonuses/create.turbo_stream.erb`, `app/policies/daily_bonus_policy.rb` -- the template for the claim controller: rate limit, `respond_to` turbo_stream/html, `failure_message`. The stream replaces `daily-booster`, `packs-chip`, `hub-menu-booster` and `hub-showcase-actions`, then appends the toast. The claim also replaces its own slot.
- `config/routes.rb:61` -- beside `resource :daily_bonus`.
- `app/views/pages/_goal.html.erb`, `app/views/live_streams/_goal.turbo_stream.erb`, `app/jobs/live_goal_job.rb` -- the broadcast replaces the whole `#community-goal` panel every ~10 s, so a claim slot inside it would be wiped. Move the public content into an inner element (e.g. `#community-goal-progress`) that the broadcast targets. The claim slot (`#goal-reward`) sits in the panel outside it and is rendered only for a player with a reward.
- `app/views/pages/_daily_booster.html.erb` -- reuse its ready / full (disabled `ButtonComponent`, orange line) / collected pattern and `ButtonComponent ... method: :post`.
- `app/views/pages/home.html.erb:34`, `app/controllers/pages_controller.rb:18` -- the goal reward toast and `@goal_reward_week`: the toast is removed with its `pages.home.goal_reward.*` keys; the controller reads the claim slot's state instead.
- `app/frontend/styles/hub.css:623-706` -- `.hub-goal*` rules; add the claim slot's rules there (no `style` attribute).
- `config/locales/{fr,en}.yml` -- `pages.home.goal.*`, `pages.home.goal_reward.*`, `pages.how_it_works.goal.reward`, `errors.game.*` (add the four `reward_*` codes by hand; the shared `reserve_full` and `no_season` messages name the daily booster).
- Do not touch: `GrantGoalRewardsJob`, `SumWeeklyGoalJob`, `Game::Reserve`, `Pack::BANK_SIZE`, `ReleasePlayer` (it already deletes the rows), `ExportOf` (`goal_reward_weeks` stays the list of earned weeks).

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/20261014130000_allow_goal_rewards_without_pack.rb`, `db/schema.rb` -- `change_column_null :game_goal_rewards, :pack_id, true`. Regenerate the schema per AGENTS.md -- the waiting state.
- [x] `packs/game/app/models/game/goal_reward.rb`, `packs/game/app/events/game/goal_reward_granted.rb`, new `packs/game/app/events/game/goal_reward_claimed.rb` (`{ player_id:, pack_id:, week_start: }`) -- model and events.
- [x] `packs/game/app/operations/game/grant_goal_reward.rb` -- earn without a pack.
- [x] new `packs/game/app/operations/game/claim_goal_reward.rb` -- `new(random:).call(player:, week_start:)`, with the failures of the matrix in its order: player, lock, earned, unclaimed, season, room.
- [x] `packs/game/app/queries/game/waiting_goal_reward.rb` -> `goal_reward_status.rb` (`Game::GoalRewardStatus`) -- the claim slot's reward state.
- [x] new `app/controllers/goal_rewards_controller.rb`, `app/policies/goal_reward_policy.rb` (`create? = player?`), `config/routes.rb` (`post "goal-rewards/:week"`, week constrained to `\d{4}-\d{2}-\d{2}`, unparsable date -> `:reward_not_earned`), `app/views/goal_rewards/create.turbo_stream.erb` -- the claim.
- [x] `app/views/pages/_goal.html.erb` (+ new `_goal_progress.html.erb`, `_goal_reward.html.erb`), `live_streams/_goal.turbo_stream.erb`, `pages_controller.rb`, `home.html.erb`, `hub.css` -- the claim slot and its states, and the broadcast's new target.
- [x] `config/locales/{fr,en}.yml` -- the copy in the Decisions; `bundle exec i18n-tasks missing` and `unused` clean.
- [x] `test/packs/game/goal_reward_test.rb` -- rewrite for the matrix (earn without a pack, claim, second claim, full reserve then room after an opening, not earned, no season, banned, the claimed pack opens like any pack). Keep the job and sum tests.
- [x] new `test/controllers/goal_rewards_controller_test.rb` -- turbo stream and HTML answers, a refusal with a full reserve in fr and en, a visitor redirected. `pages_controller_test.rb` -- the slot's waiting / full / collected states, absent for a visitor and a non-contributor, the budget unchanged. `test/jobs/live_goal_job_test.rb` -- the new target, no claim slot in the broadcast. `authorization_test.rb` if it lists the actions.

**Acceptance Criteria:**
- Given a reached week, when the grant job runs, then each contributor's reserve count is unchanged and their hub panel offers the claim.
- Given a waiting reward and a reserve under ten, when the player claims it from the hub, then the packs chip counts one more pack, the panel shows the reward collected, and reloading the hub keeps that state.
- Given ten available packs, when the player claims, then nothing is added and the toast gives the reason in the page's language. After the player opens one pack, the claim succeeds.
- Given the goal broadcast fires while the claim slot is shown, then the figures update and the slot stays.

## Implementation Notes

- `GoalRewardStatus` picks the oldest unclaimed reward, else the newest claimed one of the current or previous week, in one ordered read; `PLAYER_HUB_QUERIES` stays 19.
- The broadcast now replaces `#community-goal-progress` only; it has `display: contents` and the previous-week line `order: 1`, so the claim slot shows under the reward line while sitting outside the broadcast target. Not yet seen in a browser.
- The claim's Turbo Stream replaces the daily booster panel only when the reserve becomes full, so its primary button is not demoted otherwise.
- The goal reward toast, its `pages.home.goal_reward.*` keys and its system test are removed; `ToastComponent`'s `once:` option is now unused.
- Verified by the implementer: `bin/rails test` 2506 runs green, rubocop, packwerk, i18n-tasks missing, zeitwerk, brakeman, typecheck, vitest.

## Plan Change Log

## Review Triage Log

### Pass 1 (quick, 2026-10-14) — high 0, medium 1, low 4, false 0, maybe-false 0

- `medium` patch — a reward older than the previous week, once claimed, gave `GoalRewardStatus` nil, so the slot vanished after the claim and on reload instead of showing it collected (acceptance criterion 2); the collected state is now chosen by when the reward was claimed.
- `low` patch — collecting the daily booster that fills the reserve left the goal claim slot active without the orange line; the daily bonus stream now also replaces `#goal-reward` when the reserve becomes full.
- `low` patch — the claim button shared the daily booster's accessible name « Récupérer » on the same hub; it gets its own label.
- `low` reject — the new files' header comments describe behaviour rather than an external constraint; every operation, query, controller and partial around them carries the same header, and the new ones follow that house style without planning ids.
- `low` reject — the claim slot follows the previous-week line in the DOM though it shows above it (`order: 1`); that line is plain text, so reading it first changes no meaning and nothing focusable is reordered.

## Design Notes

The old flow drew the pack at grant time. The claim now draws it, because a pack row cannot exist without being in the reserve: `Reserve` counts every unopened available pack. "Ten packs" follows the architecture rule for the daily booster: the reserve shown, all kinds, available. The bank's `BANK_SIZE` counts regular packs only, so it is not the cap here. A reward row whose pack already exists is the collected state, so rows granted before this change need no migration: their pack is already in the reserve. The spec and EXPERIENCE still say the reward sits outside the cap (spec, weekly goal; EXPERIENCE, Special booster in the reserve). This ticket supersedes that for the claim; updating those documents is the author's.

## Verification

**Commands:**
- `bin/rails test` (system tests skipped) -- expected: green.
- `bin/rubocop` on the changed Ruby files, `bundle exec packwerk check`, `bundle exec i18n-tasks missing`, `bundle exec i18n-tasks unused`, `bin/rails zeitwerk:check` -- expected: clean.
- `RAILS_ENV=test bin/rails db:drop db:create db:migrate`, then `git diff db/schema.rb` -- expected: only `pack_id` loses `null: false`, plus the version.
- `npm run typecheck`, `npm run test:js` -- expected: green.

**Manual checks:**
- On the hub with a reached week and a contributor: claim → chip +1 and the slot shows the collected state. With 10 packs: the button is disabled and the line gives the reason. A forced POST is refused with the toast. Wait for a goal broadcast and check the slot survives.
