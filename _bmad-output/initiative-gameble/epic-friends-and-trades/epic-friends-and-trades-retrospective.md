---
epic: epic-friends-and-trades
date: 2026-10-08
verdict: accepted-with-open-items
criteria: declared
headless: false
---

A second retrospective of this epic, run on 2026-10-09 on the other line of history before the two were reconciled, is [epic-friends-and-trades-retrospective-2026-10-09.md](epic-friends-and-trades-retrospective-2026-10-09.md).

# Retrospective: Friends and trades (epic 5)

## Epic summary

**Epic:** `epic-friends-and-trades` (id 5), `_bmad-output/initiative-gameble/epic-friends-and-trades/epic-friends-and-trades.md`. Covers CAP-10, CAP-11, CAP-21; requirements R1–R6; six Done-when criteria.

**Tickets** (`tickets.py status`): all 12 have `status = built`, `state = review`. `pending_tickets` is empty, so nothing forces a rejected verdict. None is marked done; closing the epic stays with `bmad-ticket`.

| Ref | Title | Feature commit |
|---|---|---|
| 5.1 | Friend code and a first Friends screen | `2c76d06` |
| 5.2 | Invitations by code and by link | `257f83b` |
| 5.3 | Friends' presence | `60e9d86` |
| 5.4 | Trade core | `e440b7d` |
| 5.5 | Accept, counter and expire | `885f9d5` |
| 5.6 | Trades screen, server-rendered | `00a642d` (+ `9456caa` test fix) |
| 5.7 | Trade board island: picker and quantities | `cb37ba0`, `7108f7f` |
| 5.8 | Trade board island: draft, counter, swap | `5e26846` |
| 5.9 | A private stream and live updates | `e808e85` (+ `0bb5424` fix) |
| 5.10 | A friend's profile and visibility | `e2d8102` |
| 5.11 | Deleting or banning an account, empty states | `9833354` |
| 5.12 | Refactor sweep | `2d46c6a` |

**Ranges.** The plans' `baseline_revision` values are `fa1676d`, `47cea18` (5.2 and 5.4), `2c2731f` (5.3), `e419296` (5.5), `03a1649` (5.6 and 5.10), `9456caa` (5.7, 5.9, 5.11), `80054de` (5.8) and `b2e3ac3` (5.12). The stories were built in parallel lanes interleaved with epics 6, 7, 8 and 10 (for example 7.6, 6.5, 7.8 and 8.13 landed between baselines). A plan-to-plan range therefore mixes several epics, and 274 commits fall between the first baseline and HEAD. Attribution was done by commit subject instead: 31 commits name a 5.x story, 14 of them merges, and every ticket has exactly one feature commit. `git_evidence.py` was run once over `fa1676d~1..HEAD` with all twelve ids; its `files` list is epic-mixed, so per-file churn was recomputed from the epic's own non-merge commits. 5.4's range is empty (it shares a baseline with 5.2), and 5.2 and 5.1 each have a duplicate commit on a worktree branch that is not on the spine.

Two commits outside any ticket touch the epic's code: `0bb5424` (a live-refresh fix) and `2966aaf` (trade picker filters, its own plan `_bmad-output/backlog/story-trade-picker-filters-plan.md`, 2026-10-07 22:30). They are read as part of the cumulative result and flagged where they matter.

**Evidence inventory.**

- Available: epic file, initiative file, `tickets.toml`, twelve plans, git history, `deferred-work.md`, `pending-approvals.md`, the three review lenses of this run.
- Missing: story files (no ticket was refined); transcripts of the build subagents; any orchestrator session log after 2026-10-07 14:06 (the last log of that day ends before 5.6 to 5.12 were merged). Process-lesson analysis is therefore skipped, and the retro says so.
- Narrowed: the pre-pass was rebuilt per commit (see Ranges); Ruby tests ran on Ruby 4.0.5 because the pinned 4.0.7 is not installed here.

## Findings

Dispositions: **fix** (fix now), **defer**, **accept**. Sources are file and line at HEAD.

### Aggregate views

- **Architecture delta: clean.** `bundle exec packwerk check` reports no offenses and no stale violations. `zeitwerk:check` passes. Pack dependencies follow the diagram. Disposition: accept.
- **Size growth: no god class.** Largest non-test files at HEAD: `app/frontend/styles/trades.css` (940 lines, +991/−51 over seven tickets), `config/locales/fr.yml` and `en.yml` (shared by 12 tickets), `app/controllers/trades_controller.rb` (202 lines, +307/−105, six tickets), `app/frontend/components/TradeBoard.tsx` (257), `TradePicker.tsx` (260), `app/helpers/trades_helper.rb` (178). Ticket 5.12 removed 1,072 lines. `trades.css` is the one to watch. Disposition: accept; `trades.css` is covered by epic 12's oversized-file cut.
- **Duplication: handled.** 5.12 merged the near-duplicates the parallel lanes produced (`Game::FreeCopies`, two friend-name helpers, the friendship and trade steps, the counter form's limits). No remaining duplication was found in the reviewed code. Disposition: accept.
- **Pattern divergence, planning ids (F1).** The policy forbids planning ids in code, tests, config and migrations. 5.12 cleaned code, tests, CSS and config, but six lines remain in five migrations the epic created: `db/migrate/20261007120000_create_game_friend_codes_and_friendships.rb:1`, `20261007130000_create_game_trades.rb:1,6`, `20261007145300_add_presence.rb:1`, `20261007183100_add_token_to_game_trades.rb:1`, `20261007183102_index_game_trades_on_token.rb:1`. Older epics carry hundreds more (828 hits repo-wide under `app packs config db test script`), which epic 12 R2 targets. Disposition: defer to epic 12; the migrations are not named in R2's wording, so add them there.
- **Spec-to-implementation reconciliation.**
  - Done when 1, 2, 3, 4, 5 and 6 are all demonstrated by tests and by the system tests that passed (see Behavior verification). Quantity, four-card limit, reservation, 7-day expiry restarted by a counter, one open trade per pair and presence are all present.
  - One divergence from the epic's own wording: R4 says a declined or expired trade releases the cards and an expired trade moves nothing, but between `expires_at` and the next sweep the row is still `open` and keeps its reservation (F3).
  - Another: the epic's Boundaries leave SIGNALER to epic 7, yet 5.10 shipped it by reusing the report dialog. Accepted deviation, since epic 7 story 4 was built first.

### Lens findings

Three lenses ran: adversarial, edge-case, verification-gap. Overlap between them is signal and is noted. Every item was re-checked against its source unless marked.

- **F2. Accept can execute terms the player never saw.** `app/controllers/trades_controller.rb:86-95` passes only the trade token to `Game::AcceptTrade`. A counter changes the terms under the same token (`packs/game/app/operations/game/counter_trade.rb:28`), so a stale tab or second device can accept a newer offer. Checked: no terms check exists in the controller or the call. The consequence is an irreversible swap on unseen terms. Disposition: fix now (carry `proposed_at` in the accept and decline links and refuse on mismatch). Prevention: add "stale submit" to the operations' test checklist.
- **F3. An expired but unswept trade still counts as open (found by all three lenses).** `packs/game/app/models/game/trade.rb:12` defines `in_progress` as status `open` only. `Game::TradesOf.state_of` (`trades_of.rb:70-73`) already shows the trade as expired and the screen offers "trade again", but `ProposeTrade` (`propose_trade.rb:38-41`) refuses with `trade_already_open` and the offer stays reserved until `ExpireTradesJob` runs (every minute, `config/recurring.yml:26-29`). Two truths on screen, and indefinitely so if the queue is down. No test crosses the read and write sides (`test/packs/game/trades_of_test.rb:84-92` pins only the read). Disposition: fix now (expire the pair's due trade inside the lock in `ProposeTrade`) and add the controller test.
- **F4. A forged request quantity can never be accepted.** `packs/game/app/operations/game/trade_steps.rb:18-20` validates only that requested cards exist, and the controller whitelists keys, not quantity (`trades_controller.rb:169-177`). A POST asking 999 of a card held once creates a proposal that `AcceptTrade` always refuses, while the proposer's offer stays reserved up to 7 days. Checked in `propose_trade.rb:5-27`. Disposition: fix now (bound the request by the recipient's holdings in `ProposeTrade` and `CounterTrade`).
- **F5. Visibility is not asked by the trade board or presence (found by both lenses).** `Game::Visibility` is asked by `friend_profiles_controller.rb:6-8`, but `trades_controller.rb:150-154` lists a friend's full holdings with exact counts, and the friends list and hub count show presence, activity and last-seen, whatever the friend's setting. A private-profile friend is also unreachable for a new trade because the only entry point is the refused profile (`app/views/friend_profiles/show.html.erb:25`, `friends/_profile_dialog.html.erb:18`). The epic does not say whether friendship overrides visibility. The verification-gap lens adds that no test makes a friend private and then calls the trade board (`test/controllers/friend_profiles_controller_test.rb:79-90` pins only the profile). Disposition: defer, pending an author decision (Open questions). Prevention: the "one question every surface asks" rule needs a test per surface.
- **F6. The ban path is a contract, not yet a feature (found by all three lenses).** Nothing publishes `Accounts::PlayerBanned` (`grep` over `app packs config` finds only subscribers and the event class), and the sweep `Game::DropFriendsAndTradesJob` is run only by a rake task, absent from `config/recurring.yml`. `Accounts::BanPlayer` belongs to epic 7's moderation ticket, which is still `planned`. Until it lands, a banned player's trades stay open with reservations and the partner cannot cancel, because `TradesOf` hides them (`trades_of.rb:48`). Every ban test supplies the missing publisher by hand (`test/packs/game/drop_friends_and_trades_test.rb:36-38`), so the green suite says nothing about the real path. Disposition: defer to epic 7; the moderation ticket must publish the event and the job should be scheduled. Prevention: when a handler is built ahead of its publisher, record the publisher ticket in the plan.
- **F7. Deadlock window in the deletion and ban operation (found by both lenses).** `packs/game/app/operations/game/drop_friends_and_trades.rb:25-35` locks partners found on a later pass after the player's own lock, which its own comment admits breaks the ascending lock order. A concurrent propose can abort the deletion or ban transaction, and the handler raises. The commit message `9833354` claims the lock order of AD-10, which holds only for the first batch. Disposition: fix now (retry on `ActiveRecord::Deadlocked`, or re-pluck under a first lock and relock in one sorted pass).
- **F8. Crossed invitations (found by all three lenses).** `packs/game/app/operations/game/send_invitation.rb:9-12,47` checks the reverse direction without a pair lock, so A to B and B to A can both commit as pending. Accepting one leaves the mirror pending and a second accept publishes a duplicate "new friend" notice. No concurrency test races opposite invitations. Disposition: fix now (pair lock before the reverse lookup; close the mirror on accept) with such a test. Also reported: an ignored invitation can be resent without cool-down, bounded by the 20/min throttle. Disposition: accept, tune in play.
- **F9. Presence counts live-refresh GETs.** `app/controllers/application_controller.rb:117-127` notes presence on every GET, including the Turbo refreshes fired by `app/frontend/controllers/live_refresh_controller.ts:43`, so a background tab can keep a friend "online". Reported by the adversarial lens only; not exercised. Disposition: defer, the online window is tuned in play (AD-24); confirm in play.
- **F10. Trade board has no error boundary.** `app/frontend/entrypoints/application.ts:32` registers `TradeBoard` bare, unlike the booster island (`:25-29`). A render error empties the board and the counter cannot be completed. Reported by the edge-case lens only. Disposition: defer.
- **F11. Draft storage hygiene.** `app/frontend/components/TradeBoard.tsx:94-117` and `app/frontend/lib/trade_draft.ts:28-44` restore a saved draft even in read-only mode, and counter draft keys embed `expires_at`, leaving orphan entries. Reported by the adversarial lens only. Disposition: defer to epic 12's front-end pass or a small follow-up.
- **F15. The island and its controllers have no JS unit tests.** There are none for `app/frontend/components/TradeBoard.tsx`, `TradePicker.tsx`, or `controllers/trade_board_controller.ts`, `trade_send_controller.ts` and `trade_swap_controller.ts`; only `lib/trade_*.test.ts` exist (checked with `git ls-files`). The empty-side gating of the send button, the draft kept or forgotten and the live-refresh hold are therefore pinned only by `test/system/trades_test.rb` and `live_updates_test.rb`, which CI does not run on a push to `develop` and which are flaky today (F13, F14). Reported by the verification-gap lens. Disposition: defer; add jsdom tests for `trade_send_controller` and the draft restore, or render the send button disabled server-side for an empty draft.
- **F12. Banned partners vanish from trade history.** `trades_of.rb:48` drops every trade with a banned partner, including history, and a live board turns into a 404. Part of F6; disposition: defer with it.


## Behavior verification

Run at `HEAD` (`58ab6e4`) on 2026-10-08, with Postgres 18 from `docker compose up -d` on port 5433, after `npm install` (the `pixelcrush` package was not installed locally and the first Rails run aborted at the Vite build until it was).

| Check | Result |
|---|---|
| `bin/rails test` | 1692 runs, 20547 assertions, 0 failures |
| `npm run test:js` (vitest) | 19 files, 168 tests passed |
| `npm run typecheck` | clean |
| `bundle exec packwerk check` | no offenses, no stale violations |
| `bundle exec rubocop` | 543 files, no offenses |
| `bin/rails zeitwerk:check` | all good |
| `i18n-tasks missing` (the CI gate) | none missing; `i18n-tasks health` also reports one inconsistent interpolation in a back-office key (`back_office.seasons.index.confirm.one`, epic 7) and whole-file normalization drift, neither a CI gate |
| `bin/rails test test/system/friends_test.rb live_updates_test.rb trades_test.rb` | 19 runs: 1 failure (first run) |

The system tests drive headless Chrome through the real flows (friend profile, live updates between two sessions, proposing, countering, accepting, the phone picker). Findings:

- **F13. `trades_test.rb:45` flaked once (desktop answers two trades).** On the first combined run, `assert_selector ".toast"` after clicking Accept found nothing; the screenshot shows the board still in "your turn" with the Accept button, so the click did not take effect. The test passed 3 of 3 times alone. Cause not established. Disposition: defer, investigate (the repo's known-pitfalls note already records four flaky fixes of this kind).
- **F14. `trades_test.rb:258` (phone picker) failed 3 of 4 whole-file runs.** `ElementClickInterceptedError` at the click after "Place": `click_on "Place"` matches by substring, and the board's own add buttons carry "Place" in their label, so when the picker's own button was not yet visible Capybara clicked an add button behind the open dialog, which `.trade-picker__filters` then intercepted. The first diagnosis blamed the off-ticket filters commit `2966aaf`; that was incomplete, since the ambiguous matcher dates from 5.7. CI does not run system tests on a push to `develop`, so nobody saw it. Disposition: fix now (scope the click to the picker with an exact match).

Not exercised: a manual walk through the app with a real browser session (the system tests stand in for it), and any ban flow (no publisher exists).

## Previous-retro follow-through

The previous epic in the board order is `epic-public-launch-readiness` (epic 7), which has no `epic-public-launch-readiness-retrospective.md`: it is still unfinished, with seven planned tickets. There was no previous retrospective file to follow through on. This is a missing file, not a clean record.

## Action items

All are proposed by the retrospective itself. Owners are roles, because this repo has one author. After the retrospective, items 1 to 6 were implemented on the branch `fix/friends-trades-retro-findings` (uncommitted); items 7 to 12 are not started.

1. **Accept and decline refuse stale terms (F2).** Add `proposed_at` to the accept and decline links and a `trade_changed` failure in `Game::AcceptTrade`, with tests for the counter-then-accept race. Owner: developer (remediation, story-shaped).
2. **A due trade is closed inside `ProposeTrade` (F3).** Expire the pair's due trade in the lock and release its offer before `no_open_trade`; make "trade again" and the redirect agree. Owner: developer (remediation).
3. **Bound the request quantity (F4).** Check the requested quantity against the recipient's holdings in `ProposeTrade` and `CounterTrade`. Owner: developer (remediation).
4. **Make the deletion and ban operation deadlock-safe (F7).** Retry on `ActiveRecord::Deadlocked` or lock in one sorted pass; add a concurrency test with a propose in flight. Owner: developer (remediation).
5. **Close crossed invitations (F8).** Pair lock before the reverse lookup and mirror closing on accept. Owner: developer (remediation).
6. **Stabilise the phone picker system test (F14) and investigate the Accept flake (F13).** Owner: developer.
7. **Epic 7 moderation ticket publishes `Accounts::PlayerBanned` and schedules `Game::DropFriendsAndTradesJob` (F6).** Owner: author, at the moderation ticket's start (spec reconciliation for the board).
8. **Decide whether friendship overrides profile visibility for the trade board, presence and the trade entry point (F5).** Owner: author; the answer decides a code change or a spec line. Awaiting human decision.
9. **Add the five epic migrations to epic 12's planning-id cleanup (F1).** Owner: author (spec reconciliation: R2 names code, tests and configuration but not migrations).
10. **Process: run `bin/rails test:system` for the touched files before merging a story to `develop`.** A system test of the epic was left flaky by the parallel lanes and CI never runs it. Owner: author.
11. **Add the missing crossing tests (F3, F5, F6, F15).** A controller test for propose-after-expiry, one for a private friend on the trade board, a ban test through the real publisher once it exists, and jsdom tests for `trade_send_controller`. Owner: developer.
12. **Process: when a handler is built ahead of its publisher, record the publisher ticket in the plan (F6).** Owner: author.

## Acceptance verdict

**Accepted-with-open-items**, criteria declared (six Done-when items).

- Criteria 1 to 6 are demonstrably met: the suite, the system tests and the operation tests exercise each one, and no ticket is unfinished.
- No finding makes a Done-when criterion fail on its own. F2, F3 and F4 are real defects in the trade lifecycle and are open, not blocking, because each needs a specific condition (a stale tab, an unswept expiry, a forged POST).
- The open items are F2 to F5, F7, F8, F13 and F14 as fix-now or awaiting a decision, and F6, F9 to F12 and F15 as deferred. A human decision overrides this call.

## Open questions

- Does friendship override a player's profile visibility for the trade board, presence and the trade entry point? (F5.)
- Is the Accept flake (F13) a click on a node replaced by a live refresh, or something in the form submission? Not established.
