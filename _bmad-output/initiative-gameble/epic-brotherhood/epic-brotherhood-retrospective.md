---
epic: epic-brotherhood
date: 2026-10-21
verdict: accepted-with-open-items
criteria: declared
headless: false
---

# Retrospective: The Brotherhood (epic 6, release 0.2.0)

## Epic summary

**Epic:** `epic-brotherhood` (id 6), `_bmad-output/initiative-gameble/epic-brotherhood/epic-brotherhood.md`. Covers CAP-12, CAP-13, CAP-17, CAP-19, CAP-26; requirements R1 to R7; six Done-when criteria.

**Run settings (interactive).** The user gave no going-in concern to weigh and asked for no team discussion, so Phase 3 was skipped. Phases 1, 2 and 4 ran; the document is the only file written.

**Tickets** (`tickets.py status`, build order). All 19 are `state = done`; `pending_tickets` is empty, so nothing forces a rejected verdict.

| Ref | Title | Kind | status | Feature commit(s) |
|---|---|---|---|---|
| 6.1 | Feed tracer: a public feed of notable pulls | story | done | `219fab95` |
| 6.2 | Feed fallback, filters and empty states | story | done | `20298a1a` |
| 6.3 | Weekly goal: contributions, the periodic sum and the hub panel | story | done | `79e3cd3e` |
| 6.4 | Live broadcasts and the LIVE ticker | story | done | `7879f9ec` |
| 6.5 | Goal reward: reached, missed and rollover | story | done | `6f01b154` |
| 6.6 | Repost | story | done | `5fedea5d` |
| 6.7 | First discoveries and set completion | story | done | `6ccaf91a` |
| 6.8 | The Friends tab | story | done | `3da25457` |
| 6.9 | Trades in the feed and the goal | story | done | `42d3fb5e` |
| 6.10 | Achievements engine | story | done | `7d9384fc` |
| 6.11 | The Succès screen | story | done | `3ffc125c` |
| 6.12 | Refactor sweep | story | **built** (state done) | `7f8baff5`, `79664fab` |
| 6.13 | The feed is narrower than the other screens and shows « Tout » twice | bug | done | `a3bb38cb` |
| 6.14 | The LIVE ticker sits under the top bar instead of along the bottom of the hub | bug | done | `61e8fbc1` |
| 6.15 | The LIVE ticker spans the whole window and its blinking square is red | bug | done | `0937c4db` |
| 6.16 | Reward packs get their own odds | story | done | `47f2a2ed` |
| 6.17 | The community pack is claimed with a button | story | done | `68da4820` |
| 6.18 | Players read capsule, and the Brotherhood is the Gameblers | story | done | `01a8110b` |
| 6.19 | A new player is welcomed by the Brotherhood once | story | done | `7c958209`, `c1e98350`, `4c4a991c`, `bd43e5b0` |

**Tickets still at `built`.** 6.12 "Refactor sweep": its plan `story-refactor-sweep-plan.md` has `status: built`, baseline `a4f0ff71` (2026-10-21, written by the person who ran the sweep), while the ticket `state` is `done` since `354f3855` ("the author accepted v0.2.0-rc.1 on staging"). The plan was never moved to `done`; closing it stays with `bmad-ticket`.

**Staging.** The author validated v0.2.0-rc.1 on staging on 2026-10-21 (`354f3855`; tag `v0.2.0-rc.1` points at `79664fab`, which contains the sweep `7f8baff5`). That walk-through is the author's, not this run's.

**Plan ranges.** Baselines ordered by history (oldest first; ancestry checked through commit dates and `git log`):

| Plan baseline | Tickets | Range run | Commits (merges / measured) |
|---|---|---|---|
| `47cea18b` | 6.3 | `47cea18b..5f223425` | 12 (4/4) |
| `5f223425` | 6.1 | `5f223425..e419296b` | 214 (14/14) |
| `e419296b` | 6.2, 6.5 (same baseline: one range, so the earlier build has no range of its own) | `e419296b..aa1bffb5` | 7 (3/3) |
| `aa1bffb5` | 6.7 | `aa1bffb5..45c342c7` | 145 (44/24) |
| `45c342c7` | 6.13 | `45c342c7..78764521` | 2 |
| `78764521` | 6.6 | `78764521..5fedea5d` | 1 |
| `5fedea5d` | 6.8 | `5fedea5d..3da25457` | 1 |
| `3da25457` | 6.4 | `3da25457..1c2c77e9` | 32 (2/2) |
| `1c2c77e9` | 6.14 | `1c2c77e9..224cc393` | 47 |
| `224cc393` | 6.10, 6.9 (same baseline) | `224cc393..42d2480d` | 54 (5/4) |
| `42d2480d` | 6.16 | `42d2480d..703461af` | 64 |
| `703461a` | 6.17 | `703461af..673ab9a5` | 5 |
| `673ab9a` | 6.11 | `673ab9a5..271fd0c5` | 35 |
| `271fd0c5` | 6.18 | `271fd0c5..32fee1d1` | 106 |
| `32fee1d1` | 6.15 | `32fee1d1..a4f0ff71` | 106 |
| `a4f0ff71` | 6.12 | `a4f0ff71..79664fab` (inferred end: cut at the last commit that belongs to the epic; `354f3855` and `dba2bcb7` after it are a ticket-state commit and the season-preparation epic) | 2 |
| `758d704e` | 6.19 | none: the baseline object does not exist in the repository (`git cat-file` fails) | n/a |

`git_evidence.py` ran once per distinct range (16 runs; `binary_revisions` absent). Two caveats, both from its output: the stories were built in parallel lanes interleaved with epics 5, 7, 8, 10, 13 and 14, so a plan-to-plan range mixes several epics (214 commits in 6.1's range, 145 in 6.7's, whose `merges_measured` is 24 of 44, so its churn is capped); and in later ranges almost no commit subject names a ref (`named` commits per range: 0 for 6.11, 6.16, 6.17, 6.15, 6.12). Attribution was therefore redone by subject: the feature and fix commits listed in the ticket table (23 commits, the sweep's two included). Their non-merge churn was recomputed with `git show --numstat` (pasted below under Size growth).

**Evidence inventory.**

- Available: epic file, initiative file and requirements, `tickets.toml`, 19 plans and the 6.12 story file, git history, `deferred-work.md`, `pending-approvals.md`, the previous retrospective, the tests.
- Missing: session logs for every ticket (none exist beyond what the plans record), so this is **process-lesson analysis from plans only**. 6.19's range is missing (baseline object absent). Story files exist only for 6.12 (no other ticket was refined).
- Narrowed: `bmad-review` was not invoked; the adversarial, edge-case and verification-gap lenses were run inline over three boundaries only (goal and reward packs; feed, ticker and live broadcasts; achievements and events). The rest of the epic's diff was not reviewed by these lenses in this run; each ticket's own review pass is recorded in its plan's Review Triage Log.

## Findings

Dispositions: **fix** (fix now, as an action item), **defer** (tracked elsewhere or later), **accept** (recorded so later retros stop re-flagging it). Sources are file and line at HEAD (`dba2bcb7`) unless a commit is named.

### Aggregate views

**Architecture delta: clean.** `bundle exec packwerk check`: "No offenses detected / No stale violations detected" (run in this session). The epic's flow keeps to the event rules: handlers `Game::Handlers::PackOpened`, `PackOpenedFeed`, `TradeAccepted`, `CardRepostedFeed`, `SetTierFeed`, `Achievements` are subscribed in `config/initializers/event_store.rb`; `Handlers::Achievements` only enqueues (`packs/game/app/handlers/game/handlers/achievements.rb`), and jobs leave after commit through `enqueue_after_transaction_commit = true` (`config/initializers/active_job.rb:7`); live broadcasts go through `AfterCommitBatch` (`app/models/live_stream.rb:11`). Disposition: accept. `zeitwerk:check` was not run in this session.

**Size growth: no god class.** Non-merge churn of the epic's own commits, top non-test files: `config/locales/fr.yml` +232/-117, `en.yml` +214/-101, `app/frontend/styles/hub.css` +198/-57 (947 lines at HEAD, shared with other epics), `feed.css` +183/-28 (224 lines), `shell.css` +193/-9 (1563 lines at HEAD, shared across epics), `app/views/feeds/show.html.erb` +128/-64 (68 lines), `packs/game/app/queries/game/feed_entries.rb` +104/-38, `packs/game/app/models/game/feed_entry.rb` +99/-27 (120 lines), `app/frontend/controllers/ticker_controller.ts` 108 lines. Tests dominate the volume (`test/controllers/feeds_controller_test.rb` +480, `test/packs/game/goal_reward_test.rb` +317, `feed_test.rb` +324, `achievements_test.rb` +330). `shell.css` and `hub.css` are the two to watch, and both are shared stylesheets, not epic-owned. Disposition: accept.

**Duplication map (F1).** The same "card-season id to rarity tier" mapping is written three times by the epic's handlers while a query for it exists: `packs/game/app/handlers/game/handlers/pack_opened_feed.rb:15-16` and `packs/game/app/handlers/game/handlers/trade_accepted.rb:15-16` (and inline at `packs/game/app/models/game/feed_entry.rb:93`) each do `Catalog::CardSeason.where(id: ...).where.not(rarity: nil).pluck(:id, :rarity).to_h { ... Catalog::Rarity::TIERS.key(name.to_sym) }`, which is exactly `Catalog::CardSeasonTiers.call` (`packs/catalog/app/queries/catalog/card_season_tiers.rb:10-13`, already used by `packs/game/app/models/game/pack_redraw.rb:14`). Second duplication (F2): the visibility rule for feed entries is implemented twice, with the same shape but different code, in `Game::FeedEntries.visible` (`packs/game/app/queries/game/feed_entries.rb:55-60`, viewer-aware) and in `Game::NewFeedEntries.call` (`packs/game/app/queries/game/new_feed_entries.rb:22-23`, viewer nil); a future change to who may be seen (friends-only, staff) has to be made in both. Both came from tickets built in different sessions (6.1/6.2 and 6.4). Disposition: defer, as a low-priority cleanup.

**Pattern divergence, planning ids (F3).** The policy forbids planning ids in code (AGENTS.md, Policy). Remaining in the epic's own files: `packs/game/app/models/game/weekly_goal.rb:2,9,11` (CAP-12, AD-9, "story 6.5", AD-3), `packs/game/app/models/game/feed_entry.rb:68`, `reward_draw.rb:2`, `first_discovery.rb:2`, `packs/game/app/queries/game/current_goal.rb:2`, `packs/game/app/jobs/game/sum_weekly_goal_job.rb:2-3,9`, `grant_goal_rewards_job.rb:2-3`, `packs/game/app/handlers/game/handlers/pack_opened.rb:3` and `pack_opened_feed.rb:3,7`, `config/initializers/event_store.rb` (AD-10, AD-13, AD-7, AD-14), and the test header `test/packs/game/weekly_goal_test.rb:5`. A repo-wide grep shows 275 files under `app packs config lib test db` carrying such ids, so this is not specific to the epic. The sweep commit `79664fab`, titled "the planning ids leave the epic's comments", touched only seven files (README, `packs/accounts/**`, `test/support/library_requests.rb`, the 6.12 plan): the title overstates what it did for epic 6's own code. Disposition: defer to epic `epic-human-readable-codebase`, whose scope should name these files; see action item 3.

**Spec-to-implementation reconciliation.**

- **F4. The reward model diverged from R2/R3 and Done when 1, by the author's decision.** Epic R3 says the reward booster "lives outside the cap of ten in its own zone"; Done when 1 says "every contributor receives a rare pack"; the 2026-10-07 decision says it is "outside the cap of ten ... so it is never lost". Ticket 6.17 replaced that: the grant records a reward row with no pack (`packs/game/app/operations/game/grant_goal_reward.rb`), the player claims it with a button, and the claim is refused while the reserve holds ten packs, like the daily bonus (`packs/game/app/operations/game/claim_goal_reward.rb:39,65-67`), where the reserve counts packs of any kind including `reward` (`packs/game/app/queries/game/reserve.rb:1-4,17`). The author's decisions are in the frozen Intent of `story-the-community-pack-is-claimed-with-a-button-plan.md` (lines 19-25, "Decisions (author, 2026-10-14)": "An unclaimed reward waits forever ... so none is lost"). The epic file was not updated (R2, R3, Done when 1 and the 2026-10-07 notes still describe the earlier model). Disposition: accepted deviation as built; spec reconciliation proposed (action item 1).
- **F5. The reward odds are a separate table**, one Légendaire in 50 packs (`packs/game/app/models/game/draw_odds.rb:25-29`, `packs/game/app/models/game/reward_draw.rb`), tracked as approved in `pending-approvals.md:48`. R3 fixes only "at least one Épique or better", which `RewardDraw.cards` enforces. Disposition: accept.
- **F6. Weekly target constants are the epic's** (`PER_PLAYER = 50`, `FLOOR = 200`, `packs/game/app/models/game/weekly_goal.rb:15-16`), as R2 says. A backlog story raising them to 125 and 500 exists (`e5539a09`, `_bmad-output/backlog/story-the-weekly-goal-asks-more.md`); it is outside this epic. Disposition: accept.
- **F7. The LIVE ticker carries set entries** (`TICKER_KINDS = %w[pull discovery trade set]`, `app/models/live_stream.rb:4`), though R5 lists pulls, first discoveries and trades only. The epic's own note (2026-10-08, author) assigns set tier and completion lines in the feed and ticker to ticket 13.6; reposts are correctly absent. Disposition: accept.
- **F8. Done when 6 holds.** The weekly total is written only by the periodic job (`packs/game/app/jobs/game/sum_weekly_goal_job.rb:21-29`); each player writes only their own contribution row (`packs/game/app/models/game/weekly_contribution.rb`, upsert by `(player_id, week_start)`; test `test/packs/game/weekly_goal_test.rb:32`). The job updates the goal row only when the total changed.

### Lens findings (boundaries only; narrowed scope)

Lenses run inline: adversarial, edge-case, verification-gap. Boundaries read: goal and reward packs; feed, ticker and live broadcasts; achievements and events.

**Goal and reward packs**

- **F9 (verification gap, accept).** The claim path is covered by `test/packs/game/goal_reward_test.rb` (claim, second claim, full reserve then success after an opening, no season, not earned, banned, a trade-only contributor is rewarded: lines 82-255) and `test/controllers/goal_rewards_controller_test.rb`. Checked and clean for double claims (`claim_goal_reward.rb` takes the bank lock and refuses a row that has its pack) and for a grant job enqueued every 10 seconds (one anti-join per run, rejected as low in the 6.5 triage log).

**Feed, ticker and live broadcasts**

- **F11 (left open by design, defer).** Friends-only players' entries and the Friends tab never reach the public live stream (`new_feed_entries.rb:22-23` filters with a nil viewer); a friends-only entry appears on the next page load. Recorded in the 6.12 plan as left open, a product call.
- **F12 (left open by design, defer).** The feed's visibility paging stops after `WINDOW x PASSES = 90 x 10 = 900` rows (`feed_entries.rb:28-29`); more than 900 consecutive hidden newest rows would empty the feed. Rejected as far from everyday use in the 6.2 triage log; still open in the 6.12 plan.
- **F13 (checked, clean).** Reposts never reach the ticker (`live_stream.rb:4,39-41`; test `test/models/live_stream_test.rb:100`), and an entry's live notice survives the job boundary with its timestamp (`live_stream_test.rb:111`). The ticker's loop-boundary join is covered by `app/frontend/lib/ticker.test.ts` (per the 6.12 plan); `npm run test:js` passed (below).
- **F14 (verification gap, defer).** Automated browser coverage of the live paths (ticker placement, window width, blinking square, hub gauge refresh, toasts) is the system tests, which are disabled until rebuilt (AGENTS.md, Running and verifying). What remains is Ruby model and job tests, vitest, and the author's staging walk. The 6.12 plan lists three layout items it did not verify: the `#community-goal-progress` `display: contents` layout, the `:has()` requirement and the version label floating over a scrolled band; the author's staging acceptance covers them in practice, but no recorded check names them. Disposition: defer; revisit when system tests return (action item 5).

**Achievements and events**

- **F15 (checked, clean).** Every event that moves an achievement metric triggers a grant: `Handlers::Achievements::EVENTS` lists `PackOpened`, `SetCompleted`, `CardReposted`, `TradeAccepted` (`handlers/achievements.rb:4-9`), covering the six metrics of `Game::AchievementProgress` (packs, Épiques and Légendaires held, sets completed, trades accepted, reposts). Tests cover once-only unlock, not-met and unknown keys, the concurrency of two grants and the retroactive backfill (`test/packs/game/achievements_test.rb`, `grant_achievement_concurrency_test.rb`). The backfill was run on staging and production (`pending-approvals.md:17`, settled 2026-10-20).
- **F16 (coupling, accept).** The `reposts` metric counts rows of the feed projection (`packs/game/app/queries/game/achievement_progress.rb:31`: `game_feed_entries ... kind = 'repost'`) rather than an event or a source table. Today only `Game::ReleasePlayer` deletes feed entries (`packs/game/app/operations/game/release_player.rb:9`), for the departing player, so the count is stable; if a retention of feed rows is ever added, progress (not unlocks) would drop. Disposition: accept, noted for any future feed retention.
- **F17 (left open by design, defer).** Two edges accepted in the 6.10 triage log and carried by the sweep: a held achievement toast is lost when the player leaves the booster mid-reveal, and a player banned during the backfill and later unbanned gets past milestones live with toasts.
- **F18 (card-backs contract, accept).** R6 requires the set-completed, goal-reward and achievement events to be published for card backs: `Game::SetCompleted`, `Game::GoalRewardGranted`, `Game::GoalRewardClaimed` and `Game::AchievementUnlocked` exist under `packs/game/app/events/game/`. `GoalRewardGranted` lost its `pack_id` in 6.17 (`goal_reward_granted.rb`: `data = { player_id:, week_start: }`), and the pack now arrives with `GoalRewardClaimed`. `epic-card-backs.md` (lines 19 and 32) speaks of "contributing to a successful weekly goal", so its author should know the pack-bearing event is the claim; no consumer exists yet.

### Process findings (from plans and git only; no session logs)

- **F19. The deferred findings the sweep left open are tracked nowhere but in a built plan.** The 6.12 plan records 14 "left open on purpose" product or design calls and four "left open, negligible" ones in its Implementation Notes (`story-refactor-sweep-plan.md`, Implementation Notes). None of them appears in `deferred-work.md` (a search for the 900-row bound, the broadcast change detection, the held toast, the unban case, one grant job per event, the toast region under a modal, `game:benchmark_open_pack`, the friends tab empty line and the `aria-pressed` note returned no line) or as a ticket. The ticket asked that "every deferred finding is fixed, recorded or dropped with a reason": they are recorded, but only in a plan whose status is `built`. Disposition: fix (action item 2).
- **F20. 6.12's Verification lists commands with expected results but records no results** (`story-refactor-sweep-plan.md`, Verification), where 6.18's plan records its run (2547 runs, 0 failures; `story-players-read-capsule-and-the-brotherhood-is-the-gameblers-plan.md`, Verification). Review is `none`. The change itself is one CSS rule and comment edits plus a disposition list, so the risk is low; the tests below were run again in this retro. Disposition: accept; process note in action item 4.
- **F21. Baselines and attribution were fragile.** Plan 6.19's `baseline_revision` (`758d704e606c265b82ea1dcdafcf744a34cd6ec4`) does not resolve in this repository, and 6.11 and 6.17 record 7-character hashes; the lanes ran in separate worktrees and history was reconciled afterwards. After ticket 6.10, commit subjects stopped naming the ticket (`feat(goal): ...`, `feat(game): ...`), so `git_evidence.py` found no `stories` for 6.11, 6.15, 6.16 and 6.17. Disposition: fix as a process rule (action item 4).
- **F22. Review-found defects in the plans cluster on one rule.** In many of the plans' Review Triage Logs, a finding is a new explanatory comment against AGENTS.md's comment rule or a planning id in a comment (for example the logs of 6.4, 6.6, 6.8, 6.9, 6.10, 6.11, 6.13, 6.14 and 6.19), each fixed by the review pass. The rule is therefore enforced by review, not by the build; F3 shows what survives when no review looks. Disposition: process lesson for action item 4 (a mechanical check would remove a recurring review cost).
- **F23. Plan amendments came from review, not from the first plan.** 6.6 (repost) and 6.10 (achievements) each needed a "Review pass 1" amendment of the plan for real defects: a repost toast drawn under the modal backdrop, a feed-entry check that would have rejected trade rows (`story-repost-plan.md`, Plan Change Log), an achievement racing an account deletion and a toast spoiling the booster reveal (`story-achievements-engine-plan.md`, Plan Change Log). Both are fixed and covered by tests. Boundary issues between tickets (the check constraint met by trades, the toast met by the reveal) were found by the reviewer, not at planning. Disposition: accept; noted as the reason the boundaries lens above looked at the same seams.

## Behavior verification

**Staging walk-through by the author, not by this run.** The author validated v0.2.0-rc.1 on staging on 2026-10-21 (`354f3855`). That covers the running system; nothing below replaces it.

**What this run exercised.** No server and no system test was started (system tests are being rebuilt, and the checkout holds another session's work in progress). The following ran against an isolated test database (`gameble_test_retro_brotherhood`, created for this run from `db/schema.rb` and dropped afterwards; `git status` stayed clean):

- `bin/rails test` on 25 non-system files for feed, goal, reward, repost, friends, achievements, discoveries and live streams: `test/packs/game/{feed,goal_reward,weekly_goal,achievements,achievement_board,earned_achievements,grant_achievement_concurrency,first_discovery_and_complete_set,first_discovery_concurrency,repost_card,friend_profile_queries,friends_presence}_test.rb`, `test/controllers/{achievements,feeds,friends,friend_profiles,goal_rewards,reposts,welcomes}_controller_test.rb`, `test/models/live_stream_test.rb`, `test/jobs/{live_feed,live_goal}_job_test.rb`, `test/policies/{achievement,goal_reward,repost}_policy_test.rb`: **277 runs, 2032 assertions, 0 failures, 0 errors, 0 skips**.
- `npm run test:js`: **46 files, 504 tests passed**.
- `bundle exec packwerk check`: no offenses, no stale violations.
- A throwaway probe in the scratchpad (not in the repo, since removed) tried to conclude a trade with an empty offer to see whether it would count in the feed and the goal: acceptance is refused with `trade_side_empty`, so the suspected gap does not exist. Nothing further came of it.

**Not run:** the full `bin/rails test` suite, `bin/rails test:system`, `npm run typecheck`, `bin/rubocop`, `bin/rails zeitwerk:check`, `bin/ci`, `i18n-tasks`. The epic's other test files (for example `pages_controller_test.rb`, which carries the hub and welcome panels) were not re-run here. No browser, so layout, the ticker's motion and the live updates were not observed by this run.

**Done-when against what ran** (each criterion below names the test or code that shows it; the author's staging walk is the end-to-end observation):

1. Gauge and reward: `weekly_goal_test.rb` (openings and trades count, periodic sum, target), `goal_reward_test.rb` (reward earned by every contributor, claim gives the pack). Met, with the claim model of F4.
2. Feed readable signed out, with trades, reposts, Friends tab: `feeds_controller_test.rb` (stranger and visitor reads: lines 42, 338; Friends only friends' entries: 264, 328; trade and repost rows: 203, 465), `feed_test.rb`.
3. Repost of an owned card, refusal of an unowned one: `repost_card_test.rb:24,56,66`, `reposts_controller_test.rb`.
4. Fallback to lower rarities, never empty while activity exists: `feed_test.rb:53,171,190`, `feeds_controller_test.rb:66` (the empty state only when nothing exists).
5. Achievement granted and shown: `achievements_test.rb`, `achievements_controller_test.rb`, `achievement_policy_test.rb`.
6. No row written by every player: F8.

## Previous-retro follow-through

The previous epic in board order is `epic-friends-and-trades` (id 5). Its `epic-friends-and-trades-retrospective.md` exists with 12 action items (a second file, `epic-friends-and-trades-retrospective-2026-10-09.md`, covers the other line of history and was not used). Following the acceptance rule: one line per item.

1. Accept and decline refuse stale terms (F2). Owner: developer. **Landed**: `trade.revision == revision ? Success() : Failure(:trade_changed)` at `packs/game/app/operations/game/trade_steps.rb:65`, commit `5a8148d2` ("the epic 5 retrospective fixes: answers check the terms seen ...").
2. A due trade is closed inside `ProposeTrade` (F3). Owner: developer. **Landed**: `step expire_due_trade(player, recipient)` at `packs/game/app/operations/game/propose_trade.rb:11,44`, same commit.
3. Bound the request quantity (F4). Owner: developer. **Landed**: `requestable` returning `:request_exceeds_holdings` at `trade_steps.rb:30-32`.
4. Make the deletion and ban operation deadlock-safe (F7). Owner: developer. **No evidence found** in a quick read (I did not open `release_player.rb`'s locking beyond its first lines).
5. Close crossed invitations (F8). Owner: developer. **Landed**: "crossing and ignored invitations settle under the pair lock", commit `5a8148d2`.
6. Stabilise the phone picker system test (F14) and investigate the Accept flake (F13). Owner: developer. **No evidence found**; system tests are now disabled until rebuilt (AGENTS.md), which makes the item moot rather than done.
7. Epic 7 moderation ticket publishes `Accounts::PlayerBanned` and schedules the cleanup (F6). Owner: author. **Landed**: `packs/accounts/app/operations/accounts/ban_player.rb:37` publishes `PlayerBanned`, and the handler is subscribed (`config/initializers/event_store.rb`, `Game::Handlers::PlayerBanned`).
8. Decide whether friendship overrides profile visibility for the trade board (F5). Owner: author. **No evidence found** of an answer in the files read; `trade_steps.rb:40-41` enforces `own_profile_private` and `friend_profile_private`, which suggests the answer was "no override", but no decision record was located.
9. Add the five epic migrations to epic 12's planning-id cleanup (F1). Owner: author. **Not landed**: all five migrations still carry planning ids (`db/migrate/20261007120000_create_game_friend_codes_and_friendships.rb:1`, `20261007130000_create_game_trades.rb:1,6`, `20261007145300_add_presence.rb:1`, `20261007183100_add_token_to_game_trades.rb:1`, `20261007183102_index_game_trades_on_token.rb:1`); 33 migration files carry such ids.
10. Run `bin/rails test:system` for touched files before merging a story to `develop`. Owner: author. **Superseded**: AGENTS.md now disables system tests as a check of work until they are rebuilt.
11. Add the missing crossing tests (F3, F5, F6, F15). Owner: developer. **No evidence found**.
12. When a handler is built ahead of its publisher, record the publisher ticket in the plan (F6). Owner: author. **No evidence found** (this epic had no such case that this run saw).

## Action items

Owners are roles; the repo has one author. Items 1 and 3 are spec reconciliations and 2 and 4 are process or tracking changes, all proposed for the human to apply; none was applied.

1. **Reconcile epic R2/R3 and Done when 1 with the claim model (F4).** Rewrite the wording that says the reward booster "lives outside the cap of ten" and that every contributor "receives" a rare pack, and the 2026-10-07 notes, to the model of 6.17: earned as a waiting reward, claimed by a button, refused while the reserve holds ten packs; and tell `epic-card-backs.md` that the pack-bearing event is `Game::GoalRewardClaimed`. Owner: author (spec reconciliation, proposed).
2. **Record the 18 findings the sweep left open (F19).** Move the list from `story-refactor-sweep-plan.md` into `deferred-work.md` (or tickets, for the ones the author wants built), each with its source, so it does not live only in a plan at `built`. Owner: author; the developer session can draft the entries.
3. **Put the epic's remaining planning ids and the five friends-and-trades migrations in the scope of `epic-human-readable-codebase` (F3, previous-retro item 9).** Files: the list under F3. Owner: author (spec reconciliation, proposed). Optional: use `Catalog::CardSeasonTiers` in the two handlers and share the feed visibility rule between `FeedEntries` and `NewFeedEntries` (F1, F2) as part of the same cleanup. Owner: developer (remediation).
4. **Process rules for the next epics (F20, F21, F22).** (a) A plan's Verification records the results of the commands it lists, as 6.18 does. (b) A plan's `baseline_revision` is a full hash of a commit that stays reachable, and a ticket's commits name its ref in the subject, so the retrospective pre-pass can attribute them. (c) Check planning ids and new comments mechanically before review (the comment rule is the most repeated review finding in this epic). Owner: author.
5. **When system tests are rebuilt, cover the live paths first (F14).** The hub gauge refresh, the ticker (placement, window width, red square, loop join), the achievement toast during a reveal and the repost toast in the phone zoom; and name the three layout items the sweep did not verify. Owner: author.

Total: 5 action items.

## Acceptance verdict

**accepted-with-open-items** (criteria **declared**: the epic file has six Done-when lines).

- Every ticket of the epic is finished: `pending_tickets` is empty. 6.12 is at `built` with `state = done`; this does not make it unfinished, and it is recorded above.
- The six Done-when criteria are demonstrated by the code and the tests read and run in this retro (277 Ruby runs and 504 vitest tests green, packwerk clean) and were accepted by the author on staging on 2026-10-21 (`354f3855`). Criterion 1 is met in a changed form (F4): the contributor collects the pack by a button instead of receiving it, by the author's decision; the epic text lags behind.
- No blocking finding stands. The open items are: the epic file and the card-backs epic need reconciling (action item 1), the sweep's left-open findings are tracked only in a plan (item 2), planning ids remain in the epic's code (item 3), and live paths have no active browser tests (item 5).
- The verdict rests on a narrowed review: the code lenses ran on three boundaries only, not on the whole diff; each ticket's own review pass is the evidence for the rest.

## Open questions

- Should the 14 product and design calls the sweep left open (the 900-row feed bound, the goal broadcast without change detection, friends-only entries not broadcast live, the achievement toast lost on leaving the booster, and the others in `story-refactor-sweep-plan.md`) be built, deferred with a date, or dropped? Only the author can say; the answer changes whether `deferred-work.md` or the board carries them.
- Was the profile-visibility question for the trade board (previous-retro item 8) decided? The code suggests no override, but no record was found.
- Is the plan of 6.12 to be moved from `built` to `done` by `bmad-ticket`, now that the ticket is done and the author accepted v0.2.0-rc.1?
- Should the card-backs epic read `Game::GoalRewardClaimed` rather than `GoalRewardGranted` for "contributing to a successful weekly goal"?
