---
title: 'The menu shows how many friend invitations wait for the player''s answer'
type: 'feature'
ticket: '10'
created: '2026-11-01'
status: 'built'
baseline_revision: 'cbe76d29acc02919220c5c2f29b7db5d1b56de62'
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

**Problem:** A player learns of a friend invitation only by opening Amis; nothing in the menu says one waits for their answer.

**Approach:** Count the invitations the player received and has not answered (pending, from a sender in good standing) and show the orange count badge, built like the trades-waiting badge, on 05 AMIS in the desktop hub menu, on the phone's PLUS tab and on the Amis row of the PLUS list; refresh all three through the player stream on every friends notice, and make ignoring an invitation publish an event so it too refreshes the badge live.

## Boundaries & Constraints

**Always:** A sent invitation never counts; an ignored or accepted one never counts; an invitation from a banned or deleted sender never counts (same rule as `Game::InvitationsOf#received`). The number is part of the link's accessible name (visually-hidden text, the visible number `aria-hidden`). Tab bar badge hidden at zero; the hub menu's and the PLUS list's (both are menu-item rows) greyed at zero (`menu-item__badge--zero`). One count query per request, shared by the menu, the PLUS list and the tab bar (memoized shell helper). Every new string in `en.yml` and `fr.yml` (French with a `zero` form and U+202F where typography requires). The ignore event goes to the recipient only: the sender's view of an ignored invitation stays "pending" and must not learn of it.

**Never:** No JavaScript for the badge (server-rendered partials updated by turbo stream). No database id in DOM ids or stream payloads. No change to the trades badge's behavior. No schema change (the `recipient_id` index serves the count). No planning ids in code.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Received | Max sends Hugo an invitation | Hugo: badge 1 on AMIS, PLUS tab and PLUS Amis row, live; Max: no count (0) | No error expected |
| Accepted | Hugo accepts | Hugo's badge goes to 0 live (tab hidden, menu greyed) | No error expected |
| Ignored | Hugo ignores | Hugo's badge goes to 0 live; Max gets no notice | No error expected |
| Cancelled | Max cancels | Hugo's badge goes to 0 live | No error expected |
| Banned sender | Max is banned | Max's invitation no longer counts for Hugo | No error expected |
| Visitor | no player | No badge slots rendered, no query | No error expected |

</intent-contract>

## Code Map

- `app/domains/game/app/queries/game/trades_waiting.rb` -- model for the new `Game::InvitationsWaiting.call(player)` query (returns 0 for nil): `Invitation.pending.where(recipient_id:)` with `sender_id` in `Accounts::Player.in_good_standing.select(:id)`, `.count`.
- `app/domains/game/app/operations/game/ignore_invitation.rb` -- publishes nothing today; add `publish(InvitationIgnored.new(data: { invitation_id:, sender_id:, recipient_id: }), stream_name: stream_name(player.id))` inside the transaction, as `cancel_invitation.rb` does.
- `app/domains/game/app/events/game/invitation_cancelled.rb` -- copy for `invitation_ignored.rb`.
- `app/models/player_stream.rb` -- add `Game::InvitationIgnored` to `INVITATION_EVENTS`; in `notices`, map it to `[ friends_notice(data[:recipient_id]) ]` only. Subscription happens through `PlayerStream::EVENTS` in `config/initializers/event_store.rb` (no change there).
- `app/jobs/player_stream_job.rb` -- add `invitations: (Game::InvitationsWaiting.call(player) if topics.include?("friends"))` to `locals`.
- `app/views/player_streams/_update.turbo_stream.erb` -- `unless invitations.nil?`, update `menu-friends-badge`, `plus-friends-badge` (both with the menu badge partial) and `tab-more-badge` (tab partial).
- `app/helpers/shell_helper.rb` -- add memoized `shell_invitations_waiting` beside `shell_trades_waiting`.
- `app/views/pages/_menu_trades_badge.html.erb`, `app/views/shell/_tab_trades_badge.html.erb` -- templates to copy into `pages/_menu_invitations_badge.html.erb` and `shell/_tab_invitations_badge.html.erb` with the new locale keys.
- `app/views/pages/_menu_friends.html.erb` -- add `<span id="menu-friends-badge" class="stream-slot">` after the online meta, before the arrow; `_menu.html.erb` passes `invitations: shell_invitations_waiting`.
- `app/views/pages/more.html.erb` -- Amis row gets `<span id="plus-friends-badge" class="stream-slot">` after its label.
- `app/views/shell/_tab_bar.html.erb` -- `:more` tab gets `<span id="tab-more-badge" class="stream-slot">`, like `:trades`.
- `config/locales/{en,fr}.yml` -- `pages.home.menu.trades_waiting` and `shell.tabs.trades_waiting` are the models; add `pages.home.menu.invitations_waiting` and `shell.tabs.invitations_waiting`.
- Existing CSS (`menu-item__badge--alert`, `--zero`, `tab-bar__badge--alert`) suffices; no CSS expected.
- Tests to mirror: `test/domains/game/trades_of_test.rb` (TradesWaiting), `test/domains/game/invitation_test.rb`, `test/models/player_stream_test.rb`, `test/jobs/player_stream_job_test.rb`, `test/integration/player_stream_tag_test.rb` ("menu 04 and the tab hold the badge slots"), `test/helpers/shell_helper_test.rb`, `test/system/live_updates_test.rb` (phone size via `resize_to`, restore it in `ensure`; see `test/system/booster_reserves_test.rb:78`). `test/controllers/pages_controller_test.rb` `PLAYER_HUB_QUERIES` (21) gains the one count query; update its comment.

## Tasks & Acceptance

**Execution:**
- [x] `app/domains/game/app/queries/game/invitations_waiting.rb` -- add the query -- the count the badge shows.
- [x] `app/domains/game/app/events/game/invitation_ignored.rb`, `app/domains/game/app/operations/game/ignore_invitation.rb` -- add and publish the event -- ignore must refresh the badge live.
- [x] `app/models/player_stream.rb`, `app/jobs/player_stream_job.rb`, `app/views/player_streams/_update.turbo_stream.erb` -- route the ignore notice to the recipient and broadcast the three badge updates on friends notices.
- [x] `app/helpers/shell_helper.rb`, `app/views/pages/_menu.html.erb`, `app/views/pages/_menu_friends.html.erb`, `app/views/pages/_menu_invitations_badge.html.erb`, `app/views/pages/more.html.erb`, `app/views/shell/_tab_bar.html.erb`, `app/views/shell/_tab_invitations_badge.html.erb` -- render the slots and badges.
- [x] `config/locales/en.yml`, `config/locales/fr.yml` -- en `one: "%{number} invitation waiting for your answer"`, `other: "%{number} invitations waiting for your answer"`; fr `zero`/`one: "%{number} invitation en attente de votre réponse"`, `other: "%{number} invitations en attente de votre réponse"`, under both keys.
- [x] Tests: query (pending received counts; sent, ignored, accepted, banned sender don't; nil → 0), ignore event published once on the recipient's stream, PlayerStream ignore notice for the recipient only, job broadcasts the three badge updates in en and fr (1 and greyed 0 / hidden 0), helper memoizes one query, integration slots on hub / PLUS / tab, `PLAYER_HUB_QUERIES` +1, system test below.

**Acceptance Criteria:**
- Given Hugo on the hub (desktop) in English, when Max's invitation is delivered, then 05 AMIS shows the orange 1 and its accessible text "1 invitation waiting for your answer" without a reload; when Hugo ignores it (or accepts it), the badge returns to the greyed 0 without a reload.
- Given Hugo at phone size on the PLUS screen in French, when Max's invitation is delivered, then the PLUS tab and the Amis row both show 1 ("1 invitation en attente de votre réponse") without a reload, and the tab's badge disappears once it is answered.
- Given Max sent the invitation, when he views the hub, then his 05 AMIS badge reads the greyed 0 and his PLUS tab carries no badge.

## Implementation Notes

- A first run was interrupted mid-implementation; this run kept its query, event, stream routing, partials, helper, views, locales and unit tests, and added what was missing: the integration slot tests (hub, PLUS, tab, visitor), the French 05 assertion and `PLAYER_HUB_QUERIES` 22 in `test/controllers/pages_controller_test.rb`, and the system tests in `test/system/live_updates_test.rb` (desktop receive/ignore with the sender at zero, phone PLUS in French receive/accept, the cancel test now checks the PLUS tab badge clears).
- Surprise: the tab bar renders on every signed-in page, so its invitations count adds one query to every signed-in full-page budget, not just the hub. Bumped by one (counts, test names and comments) in `test/controllers/library_set_test.rb`, `cards_controller_test.rb`, `library_controller_test.rb` and `public_profiles_controller_test.rb`; Turbo-Frame and visitor budgets are unchanged.
- No CSS, no JavaScript, no migration.

## Plan Change Log

## Review Triage Log

### 2026-11-01 — Review pass
- verdicts: 2 findings — high 0, medium 0, low 2, false 0, maybe-false 0
- findings:
  - `[low]` `[patch]` The desktop system test's check that the sender's badge stays at zero passed on the first render, so it proved nothing about the live update — patched: before delivery the test empties Max's 05 badge slot and plants a stray PLUS tab badge, so the greyed 0 coming back and the tab badge going away require the broadcast; it also asserts Max's page did not reload.
  - `[low]` `[patch]` The phone system test hard-coded `resize_to(390, 844)` where other system tests use a `PHONE` constant — patched: `PHONE = [ 390, 844 ].freeze` in `LiveUpdatesTest`, and `resize_to(*PHONE)`.

## Design Notes

The PLUS list rows are menu-item rows, so the "greyed at zero in the menu" rule applies to the Amis row there; only the tab bar hides its badge at zero. Friends notices already reach both players on send, accept, cancel, friend removal and a counterpart's ban or deletion (`Game::Counterparts` includes invitation senders), so computing the count on every friends notice covers every way the number changes except ignore, which gets its event.

## Verification

**Commands:**
- `bin/rails test test/domains/game test/models/player_stream_test.rb test/jobs/player_stream_job_test.rb test/integration test/helpers test/controllers` -- expected: green
- `bin/rails test test/system/live_updates_test.rb` -- expected: green
- `bin/rails test` and `bin/rails zeitwerk:check` -- expected: green
- `bundle exec packwerk check`, `bin/rubocop` on touched files, `bundle exec i18n-tasks health`, `script/check_planning_references`, `script/check_file_sizes` -- expected: clean

## Auto Run Result

**Summary:** Friend invitations the player received and has not answered (pending, from a sender in good standing) get the orange count badge on 05 AMIS in the desktop hub menu, on the phone's PLUS tab and on the Amis row of the PLUS list. The number is part of the link's accessible name. It is greyed at zero in the menu rows and hidden at zero on the tab. It updates live through the player stream on every friends notice. Ignoring an invitation now publishes `Game::InvitationIgnored`, which only the recipient's stream hears.

**Files changed:**
- `app/domains/game/app/queries/game/invitations_waiting.rb`: the count (0 for a visitor, no query).
- `app/domains/game/app/events/game/invitation_ignored.rb`, `app/domains/game/app/operations/game/ignore_invitation.rb`: the ignore event, published on the recipient's stream.
- `app/models/player_stream.rb`: routes the ignore event to the recipient alone.
- `app/jobs/player_stream_job.rb`, `app/views/player_streams/_update.turbo_stream.erb`: compute the count on friends notices and update the three badge slots.
- `app/helpers/shell_helper.rb`: memoized `shell_invitations_waiting`, one query per request.
- `app/views/pages/_menu.html.erb`, `_menu_friends.html.erb`, `_menu_invitations_badge.html.erb`, `more.html.erb`, `app/views/shell/_tab_bar.html.erb`, `_tab_invitations_badge.html.erb`: the slots and badges.
- `config/locales/en.yml`, `config/locales/fr.yml`: `pages.home.menu.invitations_waiting` and `shell.tabs.invitations_waiting` (French `zero` form included).
- Tests: the query, the ignore event, PlayerStream routing and enqueueing, the job's broadcasts in en and fr, the helper's memoization, the integration slots (hub, PLUS, tab, visitor), the French 05 row and `PLAYER_HUB_QUERIES` 22, and three system tests in `test/system/live_updates_test.rb` (desktop receive/ignore with the sender at zero; phone PLUS in French receive/accept; the cancel test now checks the PLUS tab badge clears). Query budgets of signed-in full pages are raised by one in `library_set_test.rb`, `cards_controller_test.rb`, `library_controller_test.rb` and `public_profiles_controller_test.rb`, because the tab bar renders on every page.

**Review findings:** 2 patched (both low, both in the system test), 0 deferred, 0 rejected.

**Follow-up review recommendation:** false. Patched: high 0, medium 0, low 2.

**Verification:**
- `bin/rails test` (PARALLEL_WORKERS=3): 3975 runs, 0 failures.
- `bin/rails test test/system/live_updates_test.rb`: 12 runs, 0 failures (after the review patch).
- `test/system/shell_test.rb`, `hub_test.rb`, `bridge_cache_test.rb`: 42 runs, 0 failures.
- `bin/rails zeitwerk:check`: ok.
- `bundle exec packwerk check`: no offenses.
- `bin/rubocop` on the touched Ruby files: no offenses.
- `script/check_planning_references` and `script/check_file_sizes`: clean.
- `test/config` (French typography): green.
- `bundle exec i18n-tasks health`: no missing or unused keys. It still flags one inconsistent interpolation (`back_office.seasons.index.confirm.one`) and the normalization of four locale files; both already show at the baseline, checked on a temporary worktree of cbe76d29.
- No frontend file touched, so vitest, format and CSS lint were not needed.

**Residual risks:** Every signed-in full page now runs one more count query (indexed on `recipient_id`). Ignoring from the Friends screen also sends the recipient a `friends-updated` signal, so that screen refreshes once more after its own redirect, which is harmless.

