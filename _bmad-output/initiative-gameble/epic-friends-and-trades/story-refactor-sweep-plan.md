---
title: 'Refactor sweep'
type: 'refactor'
ticket: '12'
created: '2026-10-07'
status: done
baseline_revision: 'b2e3ac33827149fbe9f3ea6015d07011bbe4671e'
route: 'full'
route_source: 'auto'
review: 'quick'
review_source: 'pinned'
lenses_ran: ['quick']
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred:
  - summary: >-
      Other epics' files keep their planning ids and explanatory comments next to epic 5's code: the hub menu partial and the tab bar (both naming the trades and friends entries), pages/_invitation, Game::Visibility's header, Game::ReleasePlayer's and Game::PlayerState's headers, the event store's other lines, visibility_test.rb and delete_player_concurrency_test.rb.
    evidence: |-
      AGENTS.md forbids them everywhere; this sweep removed only epic 5's (the author's scope: other epics' code is left to their sweep, epic 12).
    location: >-
      app/views/pages/_menu.html.erb, app/views/shell/_tab_bar.html.erb, packs/game/app/models/game/visibility.rb, config/initializers/event_store.rb
    severity: low
---

<intent-contract>

## Intent

**Problem:** Epic 5's eleven stories were built partly in parallel and merged one after the other: the trades views and controller (5.6 to 5.11), the live refresh hold (5.8, 5.9), presence (5.3) and the friend profile (5.10) carry duplicated logic and seams between lanes (`Game::FreeCopies` read by nothing but its test, two friend-name functions, three copies of the "not banned, not deleted" rule, the friendship lookup written four times, the hold attribute spelled in three controllers, counter-form limits passed as three derived hashes); their code still carries planning ids and explanatory comments that AGENTS.md now forbids; and each plan's deferred list must end fixed, recorded or dropped with a reason.

**Approach:** Cleanup only, behaviour-preserving, inside the code epic 5 owns (the friends, invitations, presence, friend profile and trades surfaces, the private stream, and the Game pack's trade, friend, presence and invitation code, with their tests, CSS and config lines): remove the duplication and seams listed in the Code Map, strip planning ids and explanatory comments (keeping one-line external constraints), and close or record every deferred finding. Other epics' code is left to their own sweep.

## Boundaries & Constraints

**Always:** behaviour-preserving (same pages, copy, routes, events, operation results and failure codes); writes only through Game operations; GETs never write; no database id in URLs, DOM or props; a comment stays only when it states an external constraint (browser, Turbo, Postgres, event-store order), in one line; any visible change is recorded in Implementation Notes.

**Never:** a migration, a new route, a locale key change, a card face change, comment removal in other epics' files (only epic 5's lines of shared files: routes, event store, recurring, cable, application controller, shell helper, hub/shell CSS, pages menu partials), new features (presence on the friend profile, lazy picker faces, a ban action).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Counter form limits | own card 3 held, 1 reserved; friend card 2 held | own field max 2, friend field max 2; "nothing to place" reasons unchanged | n/a |
| Accept with a request no longer free | recipient's free copies below the request | `:requested_cards_unavailable`, nothing moves | as before |
| Invitation or trade with a friend | name present / blank | the persona name / the nameless fallback, on Amis, the profile, the trade screens, the toasts | n/a |
| Online count | a friend deleted but still in a friendship row (race) | not counted, as the list already hides them | n/a |
| Live refresh hold | board in edition or swap playing | no morph until released, as before | n/a |

</intent-contract>

## Code Map

Duplication and seams (fix each):
- `packs/game/app/queries/game/free_copies.rb` -- read by nothing but `test/packs/game/trades_of_test.rb` ("free copies…" test and header); delete both. `Game::HeldCopies#free` covers it (`held_copies_test.rb`).
- `app/helpers/friends_helper.rb#friend_name` vs `app/helpers/trades_helper.rb#trade_friend_name` (24 calls in trades views, helper, controller) vs inline `persona_name.presence || t("friends.show.nameless")` in `app/controllers/concerns/invitation_feedback.rb`, `invite_links_controller.rb#create`, `app/views/invite_links/show.html.erb`, `app/views/friends/show.html.erb:52`. Names are stored cleaned (`Accounts::SignIn#store_persona_name`), so `.presence` and `PersonaName.clean` agree: keep one `friend_name(player)` (nil-safe) and use it everywhere; drop `trade_friend_name`.
- "Not banned, not deleted": add `Accounts::Player#removed?` and scopes `in_good_standing` / `removed` (`packs/accounts/app/models/accounts/player.rb`); use them in `trades_controller.rb#tradable?`, `app/jobs/player_stream_job.rb`, `app/channels/application_cable/connection.rb`, `accept_invitation.rb#pending_for`, `trade_steps.rb#friends`, `friends_of.rb`, `invitations_of.rb`, `trades_waiting.rb`, `friends_presence.rb#online_count` (gains `deleted_at: nil`, aligning with FriendsOf), `drop_friends_and_trades_job.rb`. Other epics' checks (`application_controller.rb#current_player`, `operation.rb#require_player`, `visibility.rb`) stay.
- Friendship lookup: `trade_steps.rb#friends` and `send_invitation.rb#not_friends` call `Game::FriendshipBetween`; `friends_of.rb` and `counterparts.rb` share `Friendship.other_ids(player_id)` (pluck, flatten, minus the player). `online_count`'s SQL subquery stays (one query on the hub).
- "Persisted player, banned allowed": `create_friend_code.rb#persisted_player`, `expire_trade.rb#acting_player`, `drop_friends_and_trades.rb#require_record` → one `require_account` in `packs/game/app/operations/game/operation.rb`.
- `accept_trade.rb#requested_free` duplicates `trade_steps.rb#enough_copies`: one `enough_copies(lines, holdings, code = :insufficient_copies)`. The lock-then-reread pair (`TradeLocks.players` + `Trade.lock.find`) in accept, counter and close becomes `TradeSteps#lock_trade(trade)`.
- `trade_steps.rb#release` filter → `offer.slice(*holdings.keys)`.
- Counter-form limits: `trades_controller.rb#edit` builds `@own_max`, `@own_held`, `@friend_max` from `@own_cards`/`@friend_cards`; `edit.html.erb` passes them to `_board`, which passes `max:` to `_side` and to `trade_nothing_to_place`. Instead `_board` receives the `Game::HeldCopies` rows already passed as `own_held`/`friend_held` and `_side`/`trade_nothing_to_place` read the limit from the row (own: `free`, friend: `quantity`) through one helper `trade_card_limit(side, row)`.
- Trades views: `index`, `show`, `edit`, `new` each repeat `content_for :back_button`, `:screen_title`, `turbo_exempts_page_from_cache`; three repeat the phone back. Move these into `trades/_screen.html.erb` (phone back when `view == :board`); `trades/_phone_back.html.erb` folds into it.
- `_board.html.erb` and `_draft_board.html.erb` repeat the middle column (swap icon, message, inline error): extract `trades/_board_middle.html.erb` (`message:`).
- `trades_controller.rb#one_at_a_time` and `#refused` set the same three flashes: one `refuse(message, title:)`.
- Live refresh hold: the attribute `data-live-refresh-hold` is spelled in `live_refresh_controller.ts`, `trade_board_controller.ts`, `trade_swap_controller.ts`; new `app/frontend/lib/live_refresh_hold.ts` (`holdLiveRefresh(element, hold)`, `LIVE_REFRESH_HOLD_SELECTOR`) used by the three.
- `Game::Trade#offer_items`/`#request_items`: used only by `test/packs/game/trade_test.rb`; keep (model reads of its own association, tests read them).

Comments and planning ids (remove; keep one-line external constraints): every file under the epic's surfaces --
`app/controllers/{trades,friends,friend_profiles,invitations,invite_links}_controller.rb`, `concerns/invitation_feedback.rb`, `app/policies/{trade,friend,invitation,invite_link}_policy.rb`, `app/helpers/{trades,friends,presence}_helper.rb`, `app/models/player_stream.rb`, `app/jobs/player_stream_job.rb`, `app/channels/**`, `app/views/{trades,friends,friend_profiles,invite_links,player_streams}/**`, `app/views/pages/_menu_{trades,trades_badge,friends}.html.erb`, `app/views/shell/_tab_trades_badge.html.erb`, `app/frontend/styles/{trades,friends}.css`, `app/frontend/lib/{stream_actions,trade_*}.ts`, `controllers/{live_refresh,trade_*}_controller.ts`, `packs/game/app/{models,operations,queries,events,handlers,jobs}` trade/friend/invitation/presence files (incl. `visibility.rb`'s friend lines, `release_player.rb`'s drop lines, `player_state.rb`'s activity lines), `packs/accounts/app/{events/accounts/player_banned,jobs/accounts/note_last_seen_job,operations/accounts/note_last_seen}.rb`, and the tests of those (`test/**` files named in the epic's plans, including `test/system/{trades,friends,live_updates}_test.rb`). Shared files: only epic 5's lines of `config/routes.rb`, `config/initializers/event_store.rb`, `config/recurring.yml`, `config/cable.yml`, `app/controllers/application_controller.rb#note_presence`, `app/helpers/shell_helper.rb#shell_trades_waiting`, `app/frontend/lib/events.ts` (stream events), `app/frontend/styles/{hub,shell}.css` badge rules.

Deferred lists (decide each, record in Implementation Notes):
- 5.3 trade accept/counter activities: resolved in 5.3's merge. 5.4 banned party cannot close: resolved by 5.11. 5.5 SetCompleted on AcceptTrade: resolved (story 6.7, `AcceptTrade#completions`). 5.6 board heading focus: resolved by 5.8. 5.10 PROPOSER UN ÉCHANGE: resolved by 5.8. 5.11 picker states: resolved by 5.7's merge; partner live update: resolved by 5.9 (`PlayerStream` on `Accounts::PlayerDeleted`).
- Still open, recorded in `_bmad-output/initiative-gameble/deferred-work.md`: props weight of À VOUS boards and the counter page (5.7, 5.8, medium unverified); a console ban reaches partners only at their next render (5.9, low). `deferred-work.md`'s menu 03 and ÉCHANGES tab transitional entries gain their resolution (story 5.6).

## Tasks & Acceptance

**Execution:**
- [ ] `packs/accounts/app/models/accounts/player.rb`, `packs/game/app/operations/game/operation.rb`, `packs/game/app/models/game/friendship.rb` -- `removed?`, `in_good_standing`, `removed`, `require_account`, `Friendship.other_ids` -- shared rules in one place
- [ ] `packs/game/app/{operations,queries,jobs}/game/*` (trade, invitation, friend, presence) -- use them; `enough_copies` with a code, `lock_trade`; delete `free_copies.rb`; strip comments -- duplication and AGENTS.md
- [ ] `app/controllers/trades_controller.rb`, `app/helpers/{trades,friends}_helper.rb`, `app/views/trades/*` -- held rows for limits, `_screen` page shell, `_board_middle`, `refuse`, one `friend_name`; strip comments
- [ ] friends, invitations, invite links, friend profile, presence, player stream, channels files -- `friend_name`, standing scope; strip comments
- [ ] `app/frontend/lib/live_refresh_hold.ts` (new), the three controllers, `trades.css`, `friends.css`, `events.ts`, `stream_actions.ts` -- hold helper; strip comments
- [ ] config and shared files' epic 5 lines -- strip comments
- [ ] tests of the epic -- drop the FreeCopies test, adjust to renamed helpers, strip comments; add a model test for `removed?`/scopes and a test that the online count leaves a deleted friend out
- [ ] `_bmad-output/initiative-gameble/deferred-work.md` -- the two open items, the two resolved transitional entries

**Acceptance Criteria:**
- Given the whole suite, when run, then every non-system test, the trades, friends, live updates, hub and shell system tests, typecheck and vitest pass, with no test expectation weakened.
- Given `grep` for planning ids (story n.n, epic n, AD-n, CAP-n, R-n, DESIGN.md, EXPERIENCE.md) over epic 5's files, then nothing is found.
- Given `Game::FreeCopies`, `trade_friend_name`, `@own_max`, `requested_free`, `persisted_player`, `require_record`, then none exists any more.

## Implementation Notes

- Subagents unavailable, done in-session (implementation and the quick review lens).
- Shared rules in one place: `Accounts::Player#removed?`, scopes `in_good_standing` and `removed` (used by the trades controller, the cable connection, `PlayerStreamJob`, `AcceptInvitation`, `TradeSteps#friends`, `FriendsOf`, `InvitationsOf`, `TradesWaiting`, `FriendsPresence.online_count`, `DropFriendsAndTradesJob`, `Accounts::NoteLastSeen`); `Game::Operation#require_account` replaces `CreateFriendCode#persisted_player`, `ExpireTrade#acting_player`'s body, `DropFriendsAndTrades#require_record` and `ReleasePlayer#require_record`; `Game::Friendship.other_ids` serves `FriendsOf` and `Counterparts`; `TradeSteps#friends` and `SendInvitation#not_friends` ask `Game::FriendshipBetween`; `TradeSteps#lock_trade` is the lock-and-reread of accept, counter and close; `enough_copies` takes the failure code, so `AcceptTrade#requested_free` is gone.
- `Game::FreeCopies` deleted; its test now checks `Game::HeldCopies#free` across two open trades (`trades_of_test.rb`).
- One friend name: `FriendsHelper#friend_name` (nil-safe, `Accounts::PersonaName.clean`, else the nameless copy) replaces `TradesHelper#trade_friend_name` and the inline `persona_name.presence || nameless` of the invitation feedback, the invite link page and controller and the Friends screen's invitation rows.
- Counter form limits: `TradesController#edit` no longer builds `@own_max`, `@own_held`, `@friend_max`; `trade_board_locals` hands the `Game::HeldCopies` rows to `_board`, and `_side`, `trade_nothing_to_place` and the island's card `max` read the limit through `TradesHelper#trade_card_limit(side, row)` (own: free copies, friend: copies held).
- Trades views: `_screen` now holds the page shell the four pages repeated (back button, screen title, Turbo cache exemption, the phone's "◀ Liste" on a board view); `_phone_back` folded into it. `_board_middle` (swap icon, message, inline refusal) is shared by `_board` and `_draft_board`. The controller's `one_at_a_time` and `refused` share `show_refusal(message, title:)` (not `refuse`, which is ApplicationController's Pundit handler).
- Live refresh hold: `app/frontend/lib/live_refresh_hold.ts` (`LIVE_REFRESH_HOLD`, `holdLiveRefresh`, `liveRefreshHeld`) is the one spelling of the attribute for the live refresh, trade board and swap controllers.
- Comments: planning ids and explanatory comments removed from epic 5's Ruby, ERB, TypeScript, CSS, tests, fixture, rake tasks and its lines of `config/routes.rb`, `config/initializers/event_store.rb`, `config/recurring.yml`, `config/cable.yml`, `application_controller.rb` (`PRESENCE_MARK`, `note_presence`), `shell_helper.rb`, `events.ts`, `hub.css`, `shell.css`, `visibility.rb`, `release_player.rb`, `player_state.rb`. Kept, one line each: the event store's subscription order, the cable adapter's process constraint, Postgres's savepoint and deadlock behaviour (`CreateFriendCode`, `DropFriendsAndTrades`), the concurrency test's timeout, and the Turbo, browser and storage constraints already in the TypeScript. `accept_trade.rb`'s `completions` lost its comment with the rest of the file (written by story 6.7 inside epic 5's operation). Other epics' comments (the hub menu partial, the tab bar, `pages/_invitation`, `visibility_test.rb`, `delete_player_concurrency_test.rb`) are left to their sweep. A test name lost its "(story 5.10)".
- Visible changes: none intended. Two invisible ones: the draft board's status line gains `tabindex="-1"` like the board's (not in the tab order); `FriendsPresence.online_count` now leaves out a deleted friend still named by a friendship row (only in the instant before `DropFriendsAndTrades` removes the row), as the list already did; tested. Names on the Friends screen, the invite link page and the invitation toasts go through `PersonaName.clean`, which only differs for a legacy stored name holding invisible characters.
- Flaky assertion fixed: `trades_controller_test.rb`'s id-leak check `value="<trade id>"` also matched the packs chip's `data-countdown-seconds-value` when the countdown equalled the trade id (seen once in a parallel run); it now looks for a plain ` value=` attribute.
- New tests: `test/packs/accounts/player_standing_test.rb` (`removed?`, both scopes); `friends_presence_test.rb` (a deleted friend is neither listed nor counted).

Deferred lists of the epic (every item decided):
- Resolved before this sweep: 5.3's trade accept/counter activities (5.3's merge, `PlayerActivity::EVENTS`); 5.4's banned party cannot close (5.11, a ban drops the ties); 5.5's `SetCompleted` on acceptance (story 6.7, `AcceptTrade#completions`); 5.6's board heading focus (5.8, `trade-board` focus value); 5.10's PROPOSER UN ÉCHANGE (5.8, links to the draft); 5.11's picker states (5.7's merge, `trades.side.none.*` in the island) and partner live update (5.9, `PlayerStream` on `Accounts::PlayerDeleted`).
- Still open, recorded in `deferred-work.md`: the props weight of À VOUS boards and the counter page (5.7 and 5.8, one entry, medium unverified); a console ban reaching partners only at their next render (5.9, low, waits for the ban action of epic 7). `deferred-work.md`'s transitional menu 03 and ÉCHANGES tab entries now name their resolution (story 5.6).
- Dropped with their recorded reasons (rejected review findings, re-read against the code): 5.2's two crossing pending invitations (the second accept is idempotent); 5.4's A-for-A trade allowed and `:not_allowed` before `:trade_not_open`; 5.5's three false findings; 5.6's silent clamp of the no-JS counter field; 5.7's lost picks on a refused counter (5.8's browser draft keeps them now), "Réservée" on a partly reserved card, and the friend's collection shown whatever their visibility (author's to confirm); 5.8's leftover counter-round entries in localStorage and Turbo's location after `replaceState`; 5.9's extra self-refresh and the after-commit enqueue; 5.10's showcase wrap on a 360px phone; 5.11's past-expiry trade closed as cancelled.
- The seam between presence and the friend profile, closed (a visible change): story 5.10 left presence on the profile to 5.3, built in parallel, which put it on the friend rows only, while DESIGN.md's friend profile lists "name, presence, card count". The profile now shows the friend's presence under the name, with the friend row's markup (`friends/_presence`, shared) and words, read by `Game::FriendsPresence.of(friend)` (one query, the same windows and states as the rows). Tested in `friend_profiles_controller_test.rb` (offline, online) and `friends_presence_test.rb` (`of` agrees with the rows).
- Not a cleanup, so recorded in `deferred-work.md` instead: EXPERIENCE.md's friend row also offers "PROPOSER UN ÉCHANGE" (5.8 left the Amis row without it; the profile has it).
- Story 5.9's follow-up review (the refresh retry after a visit) found nothing new: the live updates system tests passed in this sweep's run.

## Plan Change Log

## Review Triage Log

### 2026-10-07 — Review pass
- verdicts: 4 findings — high 0, medium 0, low 3, false 1, maybe-false 0 (quick lens run in-session, subagents unavailable)
- findings:
  - `[low]` `[patch]` `Game::CreatePlayerState#persisted_player` is the same check as the new `Game::Operation#require_account`, so the acceptance criterion "no `persisted_player` left" failed and a third copy of the rule stayed — `CreatePlayerState` now calls `require_account`; its tests (player state backfill, registration handler) pass in the full suite.
  - `[low]` `[patch]` The kept ordering comment in `config/initializers/event_store.rb` said "the ties the next two drop", which a subscription inserted between them would make wrong — it now names the PlayerDeleted and PlayerBanned handlers.
  - `[low]` `[reject]` `_board_middle` gives the draft board's status line `tabindex="-1"`, which it lacked — not in the tab order, no visible or keyboard change; one partial for both boards is the point of the extraction (noted under Implementation Notes).
  - `[false]` `[reject]` Folding the page shell into `trades/_screen` could set `content_for` after the layout reads it — partials render inside the view, before the layout; the trades system tests assert the phone "◀ Liste" (board, counter, draft) and the controller test the back button, the cache meta and the title.
- Deferred (frontmatter): other epics' comments beside epic 5's code, left to their own sweep by the author's scope.

## Auto Run Result

Status: built.

- **Summary:** behaviour-preserving sweep of epic 5. Duplication and seams between the parallel lanes removed: `Game::FreeCopies` deleted; one `friend_name` (trades, invitations, invite link, Friends, profile, toasts); `Accounts::Player#removed?` with scopes `in_good_standing`/`removed` replace ten copies of "not banned, not deleted"; `Game::Operation#require_account`, `Game::Friendship.other_ids`, `FriendshipBetween` in the trade and invitation steps, `TradeSteps#lock_trade` and one `enough_copies` with its failure code; counter-form limits read from the `HeldCopies` rows (`trade_card_limit`) instead of three derived hashes; the trades pages' shell in `_screen`, the board's middle column in `_board_middle`, one `show_refusal`; one spelling of the live refresh hold (`lib/live_refresh_hold.ts`). The presence/profile seam closed: the friend profile shows the friend's presence (`Game::FriendsPresence.of`, shared `friends/_presence`), as DESIGN.md asks. Planning ids and explanatory comments removed from epic 5's code, tests, CSS, views and its config lines. Every deferred finding of the epic decided (Implementation Notes); three open items recorded in `deferred-work.md`; a flaky id-leak assertion fixed.
- **Files:** `packs/accounts/app/models/accounts/player.rb` (standing), `packs/game/app/operations/game/operation.rb` (`require_account`), `packs/game/app/models/game/friendship.rb` (`other_ids`), the Game trade, friend, invitation and presence models, operations, queries, events, handlers, jobs and rake tasks (comments, shared steps; `free_copies.rb` deleted; `create_player_state.rb`, `release_player.rb` use `require_account`), `packs/accounts` last-seen and ban files; `app/controllers/{trades,friends,friend_profiles,invitations,invite_links}_controller.rb`, `concerns/invitation_feedback.rb`, policies, `app/helpers/{trades,friends,presence}_helper.rb`, `app/channels/application_cable/connection.rb`, `app/jobs/player_stream_job.rb`, `app/models/player_stream.rb`; views `trades/*` (`_board_middle` new, `_phone_back` removed), `friends/*` (`_presence` new), `friend_profiles/*`, `invite_links/*`, `pages/_menu_{trades,friends}`; `app/frontend/lib/live_refresh_hold.ts` (new), the live refresh, trade board and swap controllers, `events.ts`, `stream_actions.ts`, `{trades,friends,hub,shell}.css`; comment lines of `config/routes.rb`, `config/initializers/event_store.rb`, `config/recurring.yml`, `config/cable.yml`, `application_controller.rb`, `shell_helper.rb`; tests of the epic (comments, the FreeCopies test moved to HeldCopies, the id-leak regex), new `test/packs/accounts/player_standing_test.rb`, new cases in `friends_presence_test.rb` and `friend_profiles_controller_test.rb`; `_bmad-output/initiative-gameble/deferred-work.md`.
- **Review:** quick lens, in-session: 2 patches (low: `CreatePlayerState` onto `require_account`; the ordering comment names its handlers), 1 deferred (low: other epics' comments, left to their sweep), 2 rejected (low: the draft status line's `tabindex`, invisible; false: `content_for` from the `_screen` partial renders before the layout).
- **Follow-up review recommended:** false (patched: high 0, medium 0, low 2).
- **Verification:** `bin/rubocop` (542 files) no offenses; `bundle exec packwerk check`, `bin/rails zeitwerk:check` clean; `i18n-tasks missing` and `unused` none; `npm run typecheck` clean; `npx vitest run` 19 files, 163 tests passed; `bin/rails test` (PARALLEL_WORKERS=2) 1679 runs, 0 failures, 0 errors; `bin/rails test test/system/{trades,friends,live_updates,hub,shell}_test.rb` (PARALLEL_WORKERS=1) 47 runs, 0 failures, run twice (before and after the profile presence and the review patches). No migration, route, locale key or card face change.
- **Residual risks:** the friend profile's presence is a visible addition (DESIGN.md's friend profile lists it; no copy added, the row's words are reused); `friend_name` now cleans names on the Friends screen and the invite link page as the trade screens already did (differs only for a legacy name holding invisible characters); the epic's remaining deferred items are in `deferred-work.md` (props weight, console ban, the friend row's trade button).

## Design Notes

`trade_card_limit(side, row)`: `row.nil? ? 0 : (side == :own ? row.free : row.quantity)`. `_side` uses it for its field's `max`, `trade_nothing_to_place(row, side, held)` for "some card still has a copy" and, on the own side, `held.key?(id)` for "held but all reserved".

## Verification

**Commands** (lane env block, `DATABASE_URL=…/gameble_test_5_12`, `RAILS_ENV=test`):
- `bin/rubocop` on changed Ruby files -- no offenses
- `bundle exec packwerk check`, `bin/rails zeitwerk:check` -- clean
- `bundle exec i18n-tasks missing` and `unused` -- none
- `npm run typecheck`, `npx vitest run` -- pass
- `bin/rails test` (PARALLEL_WORKERS=2) -- 0 failures, 0 errors
- `bin/rails test test/system/trades_test.rb test/system/friends_test.rb test/system/live_updates_test.rb test/system/hub_test.rb test/system/shell_test.rb` (PARALLEL_WORKERS=1) -- 0 failures
- planning-id grep over the epic's files -- empty
